# ---------------------------------------------------------------
# metrics-server: CPU/memory usage for `kubectl top` and the
# Horizontal Pod Autoscaler. Installed as the EKS community add-on
# (AWS-validated for this Kubernetes version); needs no AWS permissions.
# ---------------------------------------------------------------
resource "aws_eks_addon" "metrics_server" {
  cluster_name  = var.cluster_name
  addon_name    = "metrics-server"
  addon_version = var.addon_versions["metrics-server"]

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags
}
