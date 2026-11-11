data "aws_default_tags" "current" {}

locals {
  enable_efs = var.efs_file_system_id != null

  # EBS volumes are created by the CSI driver, not Terraform, so provider
  # default_tags do not reach them. Pass the same tags to the driver so
  # volumes still show up under the Project tag in Cost Explorer.
  ebs_volume_tags = merge(data.aws_default_tags.current.tags, var.tags)
}

# ---------------------------------------------------------------
# EBS CSI driver (ReadWriteOnce block volumes, one AZ each)
# ---------------------------------------------------------------
resource "aws_eks_addon" "ebs_csi" {
  cluster_name  = var.cluster_name
  addon_name    = "aws-ebs-csi-driver"
  addon_version = var.addon_versions["aws-ebs-csi-driver"]

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # Gives the controller's service account the IAM role above.
  pod_identity_association {
    role_arn        = aws_iam_role.ebs_csi.arn
    service_account = "ebs-csi-controller-sa"
  }

  configuration_values = jsonencode({
    controller = {
      extraVolumeTags = local.ebs_volume_tags
    }
  })

  tags = var.tags

  depends_on = [aws_iam_role_policy_attachment.ebs_csi]
}

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      # PVCs that name no StorageClass get this one.
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"
  # Create the volume only once the pod is scheduled, in that pod's AZ.
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type                        = "gp3"
    encrypted                   = "true"
    "csi.storage.k8s.io/fstype" = "ext4"
  }

  depends_on = [aws_eks_addon.ebs_csi]
}

# ---------------------------------------------------------------
# EFS CSI driver (ReadWriteMany shared file storage across AZs)
# ---------------------------------------------------------------
resource "aws_eks_addon" "efs_csi" {
  count = local.enable_efs ? 1 : 0

  cluster_name  = var.cluster_name
  addon_name    = "aws-efs-csi-driver"
  addon_version = var.addon_versions["aws-efs-csi-driver"]

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  pod_identity_association {
    role_arn        = aws_iam_role.efs_csi[0].arn
    service_account = "efs-csi-controller-sa"
  }

  configuration_values = jsonencode({
    controller = {
      # Deleting a PVC also deletes its directory on EFS, so test data
      # does not keep accumulating (and billing) in dev.
      deleteAccessPointRootDir = true
    }
  })

  tags = var.tags

  depends_on = [aws_iam_role_policy_attachment.efs_csi]
}

resource "kubernetes_storage_class_v1" "efs" {
  count = local.enable_efs ? 1 : 0

  metadata {
    name = "efs"
  }

  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = "Delete"
  volume_binding_mode = "Immediate"

  parameters = {
    # Each PVC gets its own EFS access point and directory.
    provisioningMode = "efs-ap"
    fileSystemId     = var.efs_file_system_id
    directoryPerms   = "700"
    basePath         = "/dynamic_provisioning"
  }

  depends_on = [aws_eks_addon.efs_csi]
}
