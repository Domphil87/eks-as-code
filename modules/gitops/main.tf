# ---------------------------------------------------------------
# Argo CD and the root "App of Apps". Terraform installs Argo CD
# once; from then on Argo CD deploys whatever is in Git under
# var.apps_path (team namespaces, applications).
# ---------------------------------------------------------------
locals {
  argocd_namespace = "argocd"
  root_app_name    = "root"
}

resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = local.argocd_namespace
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name

  values = [yamlencode({
    global = {
      domain = var.hostname
    }

    configs = {
      params = {
        # The ALB ends TLS (ACM certificate) and forwards plain HTTP
        # inside the VPC, so the server must not redirect to HTTPS.
        "server.insecure" = true
      }
    }

    # No SSO or chat notifications in dev: log in with the admin account.
    dex           = { enabled = false }
    notifications = { enabled = false }

    # Requests let the scheduler and Cluster Autoscaler plan for Argo CD.
    controller     = { resources = { requests = { cpu = "100m", memory = "256Mi" } } }
    repoServer     = { resources = { requests = { cpu = "50m", memory = "128Mi" } } }
    applicationSet = { resources = { requests = { cpu = "25m", memory = "64Mi" } } }
    redis          = { resources = { requests = { cpu = "25m", memory = "64Mi" } } }

    server = {
      resources = { requests = { cpu = "50m", memory = "128Mi" } }

      ingress = {
        enabled          = true
        controller       = "generic"
        ingressClassName = "alb"
        # hostname defaults to global.domain.
        annotations = {
          "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
          "alb.ingress.kubernetes.io/target-type" = "ip"
          "alb.ingress.kubernetes.io/group.name"  = var.alb_group_name

          # HTTPS only (HTTP redirects), modern TLS policy, ACM wildcard.
          "alb.ingress.kubernetes.io/listen-ports"    = jsonencode([{ HTTP = 80 }, { HTTPS = 443 }])
          "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
          "alb.ingress.kubernetes.io/certificate-arn" = var.acm_certificate_arn
          "alb.ingress.kubernetes.io/ssl-policy"      = "ELBSecurityPolicy-TLS13-1-2-2021-06"

          # Admin tool: only these source IPs may reach the ALB.
          "alb.ingress.kubernetes.io/inbound-cidrs" = join(",", var.allowed_cidrs)

          "alb.ingress.kubernetes.io/healthcheck-path"         = "/healthz"
          "alb.ingress.kubernetes.io/load-balancer-attributes" = "routing.http.drop_invalid_header_fields.enabled=true"

          # The controller creates the ALB, so provider default tags do
          # not reach it; pass them on explicitly.
          "alb.ingress.kubernetes.io/tags" = join(",", [for k, v in var.tags : "${k}=${v}"])
        }
      }
    }
  })]
}

# The root Application, in a local chart because its CRD only exists
# after Argo CD is installed (same reason as the ClusterIssuers).
resource "helm_release" "root_app" {
  name      = "root-app"
  chart     = "${path.module}/charts/root-app"
  namespace = kubernetes_namespace_v1.argocd.metadata[0].name

  values = [yamlencode({
    name           = local.root_app_name
    repoURL        = var.repo_url
    targetRevision = var.target_revision
    path           = var.apps_path
  })]

  depends_on = [helm_release.argocd]
}
