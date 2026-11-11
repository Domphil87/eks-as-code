# Tags from the provider's default_tags. Needed because EC2 instances and
# volumes launched by the node group's Auto Scaling group do not receive
# default_tags automatically.
data "aws_default_tags" "current" {}

locals {
  node_tags = merge(data.aws_default_tags.current.tags, var.tags, {
    Name = "${var.cluster_name}-node"
  })
}

# ---------------------------------------------------------------
# Launch template: hardening settings applied to every node
# ---------------------------------------------------------------
resource "aws_launch_template" "node" {
  name_prefix            = "${var.cluster_name}-node-"
  description            = "EKS managed node group nodes for ${var.cluster_name}"
  update_default_version = true

  # Root volume: encrypted gp3. /dev/xvda is the root device on AL2023.
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.node_disk_size_gib
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint = "enabled"
    # IMDSv2 only (session tokens): blocks a common SSRF credential-theft path.
    http_tokens = "required"
    # Hop limit 1: the token cannot cross the extra network hop into a pod,
    # so pods cannot read the NODE's IAM credentials. Each add-on gets its
    # own Pod Identity role instead (least privilege).
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags          = local.node_tags
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.node_tags
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------
# Managed node group
# ---------------------------------------------------------------
resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "default"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids

  # Amazon Linux 2023, EKS-optimized. EKS picks the latest AMI release for
  # the cluster version at creation; it is recorded in state (release_version).
  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = var.node_capacity_type
  instance_types = var.node_instance_types

  scaling_config {
    min_size     = var.node_min_size
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
  }

  # During upgrades, replace one node at a time.
  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  tags = var.tags

  lifecycle {
    # Cluster Autoscaler changes desired_size at runtime; do not fight it.
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node,
    # Nodes only become Ready once networking (vpc-cni) is installed.
    aws_eks_addon.before_compute,
  ]
}
