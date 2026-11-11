# ---------------------------------------------------------------
# Control-plane logs
# ---------------------------------------------------------------
# EKS writes to this exact log group name. Creating it ourselves (before
# the cluster) lets Terraform set retention and delete it on destroy;
# otherwise EKS creates it with "never expire".
resource "aws_cloudwatch_log_group" "cluster" {
  #checkov:skip=CKV_AWS_158:Logs use CloudWatch default encryption; no KMS key, consistent with the project's no-KMS cost decision
  #checkov:skip=CKV_AWS_338:Dev keeps 7 days to limit cost; production would keep 1 year
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# ---------------------------------------------------------------
# EKS control plane
# ---------------------------------------------------------------
resource "aws_eks_cluster" "this" {
  #checkov:skip=CKV_AWS_39:Public endpoint is needed for kubectl from a laptop; restricted to specific CIDRs (CKV_AWS_38 passes)
  #checkov:skip=CKV_AWS_58:EKS applies default envelope encryption to all Kubernetes API data with an AWS-owned key; a customer KMS key is not used to avoid cost
  #checkov:skip=CKV_AWS_37:Only audit and authenticator logs are enabled in dev to limit CloudWatch cost; enable all types in production
  #checkov:skip=CKV_AWS_339:Checkov 3.3.30 hard-codes versions up to 1.35; AWS reports 1.36 in STANDARD_SUPPORT (aws eks describe-cluster-versions)
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  enabled_cluster_log_types = var.enabled_log_types

  # Do not let EKS install unmanaged default copies of vpc-cni, kube-proxy
  # and coredns; we install all of them as managed add-ons below.
  bootstrap_self_managed_addons = false

  access_config {
    # Access is granted only through EKS access entries (AWS API),
    # not the legacy aws-auth ConfigMap.
    authentication_mode = "API"
    # Grant admin explicitly (aws_eks_access_entry.admin) instead of
    # implicitly to whoever happened to create the cluster.
    bootstrap_cluster_creator_admin_permissions = false
  }

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access_cidrs
  }

  # STANDARD: when the version reaches end of standard support, EKS
  # auto-upgrades instead of moving it to EXTENDED support, which costs
  # about 6x more for the control plane.
  upgrade_policy {
    support_type = "STANDARD"
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_cloudwatch_log_group.cluster,
  ]
}

# ---------------------------------------------------------------
# Cluster access (who can use kubectl)
# ---------------------------------------------------------------
resource "aws_eks_access_entry" "admin" {
  for_each = toset(var.cluster_admin_principal_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  type          = "STANDARD"

  tags = var.tags
}

resource "aws_eks_access_policy_association" "admin" {
  for_each = toset(var.cluster_admin_principal_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin]
}

# ---------------------------------------------------------------
# Core add-ons
# ---------------------------------------------------------------
locals {
  # DaemonSets that nodes need in order to become Ready (networking,
  # service routing, Pod Identity). Installed BEFORE the node group.
  before_compute_addons = toset(["vpc-cni", "kube-proxy", "eks-pod-identity-agent"])
}

resource "aws_eks_addon" "before_compute" {
  for_each = local.before_compute_addons

  cluster_name  = aws_eks_cluster.this.name
  addon_name    = each.key
  addon_version = var.addon_versions[each.key]

  # The add-on's settings are owned by Terraform/EKS, not edited by hand.
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags
}

# CoreDNS is a Deployment: it needs nodes to run on, so it comes AFTER them.
resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "coredns"
  addon_version = var.addon_versions["coredns"]

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags

  depends_on = [aws_eks_node_group.default]
}
