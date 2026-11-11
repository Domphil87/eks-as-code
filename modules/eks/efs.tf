# Shared file storage (ReadWriteMany) for pods on different nodes.
# The EFS CSI driver that mounts it is installed in the platform layer.

resource "aws_security_group" "efs" {
  count = var.enable_efs ? 1 : 0

  name        = "${var.cluster_name}-efs"
  description = "NFS access from EKS nodes to EFS mount targets"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.cluster_name}-efs" })
}

# Only NFS (TCP 2049) and only from members of the EKS cluster security
# group, which EKS attaches to every managed node. Security groups are
# stateful, so replies need no egress rule.
resource "aws_vpc_security_group_ingress_rule" "efs_nfs_from_nodes" {
  count = var.enable_efs ? 1 : 0

  security_group_id            = aws_security_group.efs[0].id
  description                  = "NFS from EKS nodes"
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  referenced_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

resource "aws_efs_file_system" "this" {
  #checkov:skip=CKV_AWS_184:Encrypted with the AWS-managed EFS key; no customer KMS key to avoid cost
  #checkov:skip=CKV2_AWS_18:AWS Backup disabled for disposable dev data to avoid cost
  count = var.enable_efs ? 1 : 0

  creation_token   = "${var.cluster_name}-efs"
  encrypted        = true
  performance_mode = "generalPurpose"
  # Elastic: pay per GB transferred; no provisioned throughput to forget about.
  throughput_mode = "elastic"

  tags = merge(var.tags, { Name = "${var.cluster_name}-efs" })
}

# Explicitly off for dev (see Checkov skip above).
resource "aws_efs_backup_policy" "this" {
  count = var.enable_efs ? 1 : 0

  file_system_id = aws_efs_file_system.this[0].id

  backup_policy {
    status = "DISABLED"
  }
}

# One mount target per private subnet (per AZ), so pods in every AZ can
# mount EFS locally.
resource "aws_efs_mount_target" "this" {
  for_each = var.enable_efs ? { for i, id in var.private_subnet_ids : tostring(i) => id } : {}

  file_system_id  = aws_efs_file_system.this[0].id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs[0].id]
}
