data "aws_partition" "current" {}

locals {
  # "arn:aws" in normal regions; differs in GovCloud/China.
  iam_policy_prefix = "arn:${data.aws_partition.current.partition}:iam::aws:policy"
}

# ---------------------------------------------------------------
# Cluster role: lets the EKS service manage AWS resources (ENIs,
# load balancers for Services, etc.) on behalf of the control plane.
# ---------------------------------------------------------------
data "aws_iam_policy_document" "cluster_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "${local.iam_policy_prefix}/AmazonEKSClusterPolicy"
}

# ---------------------------------------------------------------
# Node role: what the EC2 worker nodes themselves may do.
# Pods cannot use it (IMDS hop limit 1, see launch template); each
# add-on gets its own Pod Identity role in the platform layer instead.
# ---------------------------------------------------------------
data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.cluster_name}-node"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    # Join the cluster and describe the EC2 resources it needs.
    "AmazonEKSWorkerNodePolicy",
    # Pull container images from ECR (read-only; narrower than ...ReadOnly).
    "AmazonEC2ContainerRegistryPullOnly",
    # VPC CNI assigns VPC IPs to pods. It runs as a host-network DaemonSet
    # that needs credentials before anything else runs, so it uses the
    # node role. Known trade-off; see modules/eks/README.md.
    "AmazonEKS_CNI_Policy",
  ])

  role       = aws_iam_role.node.name
  policy_arn = "${local.iam_policy_prefix}/${each.value}"
}
