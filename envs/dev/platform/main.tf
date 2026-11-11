module "addons" {
  source = "../../../modules/addons"

  # From the cluster layer's state
  cluster_name       = local.cluster.cluster_name
  cluster_arn        = local.cluster.cluster_arn
  efs_file_system_id = local.cluster.efs_file_system_id

  addon_versions = var.addon_versions
  chart_versions = var.chart_versions

  parent_domain = var.parent_domain
  dns_subdomain = var.dns_subdomain

  # This environment may only read secrets named <project>/<environment>/...
  secrets_prefix              = "${var.project}/${var.environment}"
  create_demo_secret          = var.create_demo_secret
  secret_recovery_window_days = var.secret_recovery_window_days

  prometheus_retention         = var.prometheus_retention
  prometheus_storage_gib       = var.prometheus_storage_gib
  container_log_retention_days = var.container_log_retention_days

  cluster_autoscaler_version                  = var.cluster_autoscaler_version
  cluster_autoscaler_scale_down_unneeded_time = var.cluster_autoscaler_scale_down_unneeded_time
}

module "gitops" {
  source = "../../../modules/gitops"

  argocd_chart_version = var.argocd_chart_version
  hostname             = "argocd.${var.dns_subdomain}"
  acm_certificate_arn  = module.addons.acm_certificate_arn
  allowed_cidrs        = var.admin_cidrs
  alb_group_name       = "${var.project}-${var.environment}"

  repo_url        = var.gitops_repo_url
  target_revision = var.gitops_target_revision

  # Argo CD needs the Load Balancer Controller (Ingress) and ExternalDNS
  # (DNS record) running, which the addons module installs.
  depends_on = [module.addons]
}
