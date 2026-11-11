data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  iam_policy_prefix = "arn:${data.aws_partition.current.partition}:iam::aws:policy"
}

# ---------------------------------------------------------------
# Trust policy shared by every Pod Identity role.
# The EKS Pod Identity agent on each node exchanges a pod's service
# account token for these role credentials. The conditions stop any
# other cluster or account from using the role (confused deputy).
# ---------------------------------------------------------------
data "aws_iam_policy_document" "pod_identity_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [var.cluster_arn]
    }
  }
}

# ---------------------------------------------------------------
# EBS CSI controller: creates, attaches and deletes EBS volumes.
# ---------------------------------------------------------------
resource "aws_iam_role" "ebs_csi" {
  name               = "${var.cluster_name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role = aws_iam_role.ebs_csi.name
  # AWS's current recommendation for the add-on (describe-addon-configuration).
  policy_arn = "${local.iam_policy_prefix}/AmazonEBSCSIDriverPolicyV2"
}

# ---------------------------------------------------------------
# EFS CSI controller: creates and deletes EFS access points.
# AWS also lists S3 Files policies for this add-on; they are left out
# because this project does not use S3 Files (least privilege).
# ---------------------------------------------------------------
resource "aws_iam_role" "efs_csi" {
  count = local.enable_efs ? 1 : 0

  name               = "${var.cluster_name}-efs-csi"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "efs_csi" {
  count = local.enable_efs ? 1 : 0

  role       = aws_iam_role.efs_csi[0].name
  policy_arn = "${local.iam_policy_prefix}/service-role/AmazonEFSCSIDriverPolicy"
}
