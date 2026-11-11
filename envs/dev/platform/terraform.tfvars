# Dev platform settings. No secrets, so this file IS committed.

aws_region   = "us-east-1"
project      = "eks-platform-as-code"
environment  = "dev"
owner        = "Domphil87"
cost_center  = "portfolio"
state_bucket = "eks-platform-as-code-tfstate-353695163160-us-east-1"

# AWS-default versions for Kubernetes 1.36 as of 2026-11-06, from:
#   aws eks describe-addon-versions --kubernetes-version 1.36 --addon-name <name>
addon_versions = {
  "aws-ebs-csi-driver" = "v1.67.2-eksbuild.1"
  "aws-efs-csi-driver" = "v3.5.4-eksbuild.1"
  "metrics-server"     = "v0.9.0-eksbuild.14"
  "fluent-bit"         = "v5.1.5-eksbuild.2" # community add-on, added 2026-11-09
}

# Latest chart releases as of 2026-11-06 (ESO and kube-prometheus-stack
# added 2026-11-09), from:
#   helm show chart <chart> --repo <repo-url>
# The Load Balancer Controller version must match the policy file in
# modules/addons/policies/.
chart_versions = {
  "aws-load-balancer-controller" = "3.6.2"  # app v3.6.2
  "external-dns"                 = "1.23.0" # app 0.23.0
  "cert-manager"                 = "v1.21.3"
  "external-secrets"             = "2.14.0"
  "kube-prometheus-stack"        = "93.1.1" # Prometheus Operator v0.95.1
  "cluster-autoscaler"           = "9.60.0" # image tag set below
}

# Existing hosted zone (not managed by this project). Dev may only
# create records under dev.domphil.org.
parent_domain = "domphil.org"
dns_subdomain = "dev.domphil.org"

# Secrets Manager: dev may read eks-platform-as-code/dev/* only.
# The demo secret (about $0.40/month, prorated) proves the ESO sync.
# Recovery window 0 = deleted immediately on destroy, so daily
# rebuilds can re-create the same name.
create_demo_secret          = true
secret_recovery_window_days = 0

# Observability, sized for a short-lived dev cluster.
prometheus_retention         = "2d"
prometheus_storage_gib       = 10 # gp3, about $0.08/month prorated
container_log_retention_days = 7  # CloudWatch Logs

# Cluster Autoscaler: latest 1.36 patch (must match Kubernetes 1.36; the
# chart defaults to 1.37). Dev removes idle nodes after 5 minutes.
cluster_autoscaler_version                  = "v1.36.2"
cluster_autoscaler_scale_down_unneeded_time = "5m"
