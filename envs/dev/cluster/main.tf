locals {
  network = data.terraform_remote_state.network.outputs
}

module "eks" {
  source = "../../../modules/eks"

  cluster_name       = "${var.project}-${var.environment}"
  kubernetes_version = var.kubernetes_version

  # From the network layer's state
  vpc_id             = local.network.vpc_id
  private_subnet_ids = local.network.private_subnet_ids

  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs
  cluster_admin_principal_arns = var.cluster_admin_principal_arns

  enabled_log_types  = var.enabled_log_types
  log_retention_days = var.log_retention_days

  addon_versions = var.addon_versions

  node_instance_types = var.node_instance_types
  node_capacity_type  = var.node_capacity_type
  node_min_size       = var.node_min_size
  node_desired_size   = var.node_desired_size
  node_max_size       = var.node_max_size
}
