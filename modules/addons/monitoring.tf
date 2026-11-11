# ---------------------------------------------------------------
# kube-prometheus-stack: Prometheus (metrics), Grafana (dashboards),
# Prometheus Operator, kube-state-metrics and node-exporter.
# ---------------------------------------------------------------
locals {
  monitoring_namespace = "monitoring"
  grafana_admin_secret = "grafana-admin"
}

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = local.monitoring_namespace
  }
}

# Grafana admin login, stored only in Secrets Manager (same ephemeral +
# write-only pattern as demo-secret.tf) and copied in by ESO.
ephemeral "random_password" "grafana_admin" {
  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "grafana_admin" {
  #checkov:skip=CKV_AWS_149:Uses the AWS-managed aws/secretsmanager key; no customer KMS key, consistent with the project's no-KMS cost decision
  #checkov:skip=CKV2_AWS_57:Generated dev password; rotate by bumping secret_string_wo_version
  name        = "${var.secrets_prefix}/grafana-admin"
  description = "Grafana admin login, synced into the monitoring namespace by External Secrets Operator."

  recovery_window_in_days = var.secret_recovery_window_days

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "grafana_admin" {
  secret_id = aws_secretsmanager_secret.grafana_admin.id
  # Key names match the Grafana chart's admin.userKey / admin.passwordKey.
  secret_string_wo = jsonencode({
    "admin-user"     = "admin"
    "admin-password" = ephemeral.random_password.grafana_admin.result
  })
  secret_string_wo_version = 1
}

resource "helm_release" "grafana_admin_secret" {
  name      = "grafana-admin-secret"
  chart     = "${path.module}/charts/external-secret"
  namespace = kubernetes_namespace_v1.monitoring.metadata[0].name

  values = [yamlencode({
    name      = local.grafana_admin_secret
    storeName = local.cluster_secret_store
    remoteKey = aws_secretsmanager_secret.grafana_admin.name
  })]

  depends_on = [
    helm_release.cluster_secret_store,
    aws_secretsmanager_secret_version.grafana_admin,
  ]
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.chart_versions["kube-prometheus-stack"]
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name

  # The CRDs and many objects take longer than the 5-minute default.
  timeout = 600

  values = [yamlencode({
    prometheus = {
      prometheusSpec = {
        retention     = var.prometheus_retention
        retentionSize = "${var.prometheus_storage_gib - 2}GB"

        # Pick up ServiceMonitors/PodMonitors/rules from every namespace,
        # not only ones labelled for this Helm release (team apps).
        serviceMonitorSelectorNilUsesHelmValues = false
        podMonitorSelectorNilUsesHelmValues     = false
        ruleSelectorNilUsesHelmValues           = false

        resources = {
          requests = { cpu = "100m", memory = "512Mi" }
          limits   = { memory = "1536Mi" }
        }

        # StatefulSet volumes are kept by default when the app is removed,
        # which would leave an EBS volume billing after teardown. Delete
        # the PVC (and so the volume) with the Prometheus instance.
        persistentVolumeClaimRetentionPolicy = {
          whenDeleted = "Delete"
          whenScaled  = "Retain"
        }

        # Metrics survive pod restarts on an encrypted gp3 volume.
        storageSpec = {
          volumeClaimTemplate = {
            spec = {
              storageClassName = kubernetes_storage_class_v1.gp3.metadata[0].name
              accessModes      = ["ReadWriteOnce"]
              resources        = { requests = { storage = "${var.prometheus_storage_gib}Gi" } }
            }
          }
        }
      }
    }

    grafana = {
      admin = {
        existingSecret = local.grafana_admin_secret
        userKey        = "admin-user"
        passwordKey    = "admin-password"
      }
      # Dashboards and data sources are provisioned by the chart, so no
      # Grafana volume is needed.
      persistence = { enabled = false }
      # No Alertmanager data source while Alertmanager is disabled.
      sidecar = {
        datasources = {
          alertmanager = { enabled = false }
        }
      }
    }

    # Dev: no alert routing yet. The PrometheusRules still evaluate and
    # are visible in Prometheus and Grafana.
    alertmanager = { enabled = false }

    # EKS runs these on the AWS-managed control plane (or binds kube-proxy
    # metrics to localhost), so they cannot be scraped and would show as
    # permanently down.
    kubeControllerManager = { enabled = false }
    kubeScheduler         = { enabled = false }
    kubeEtcd              = { enabled = false }
    kubeProxy             = { enabled = false }
  })]

  depends_on = [
    helm_release.lbc,
    helm_release.grafana_admin_secret,
    aws_eks_addon.ebs_csi,
  ]
}
