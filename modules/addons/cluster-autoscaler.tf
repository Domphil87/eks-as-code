# ---------------------------------------------------------------
# Cluster Autoscaler: adds nodes when pods cannot be scheduled and
# removes idle nodes, within the node group's min/max size.
# Node groups are found by the tags EKS puts on their Auto Scaling
# groups; the scaling actions are only allowed on those groups.
# ---------------------------------------------------------------
locals {
  cluster_autoscaler_service_account = "cluster-autoscaler"
}

data "aws_iam_policy_document" "cluster_autoscaler" {
  statement {
    sid = "Discover"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:GetInstanceTypesFromInstanceRequirements",
    ]
    resources = ["*"] # These Describe APIs do not support resource-level permissions.
  }

  statement {
    sid       = "DescribeThisClustersNodeGroups"
    actions   = ["eks:DescribeNodegroup"]
    resources = ["arn:${data.aws_partition.current.partition}:eks:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:nodegroup/${var.cluster_name}/*/*"]
  }

  statement {
    sid = "ScaleOnlyThisClustersNodeGroups"
    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
    ]
    # EKS names managed node group ASGs "eks-<node group>-<id>".
    resources = ["arn:${data.aws_partition.current.partition}:autoscaling:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/eks-*"]

    # Tags EKS sets on every managed node group's Auto Scaling group.
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/k8s.io/cluster-autoscaler/${var.cluster_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/k8s.io/cluster-autoscaler/enabled"
      values   = ["true"]
    }
  }
}

resource "aws_iam_policy" "cluster_autoscaler" {
  name   = "${var.cluster_name}-cluster-autoscaler"
  policy = data.aws_iam_policy_document.cluster_autoscaler.json

  tags = var.tags
}

resource "aws_iam_role" "cluster_autoscaler" {
  name               = "${var.cluster_name}-cluster-autoscaler"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  role       = aws_iam_role.cluster_autoscaler.name
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
}

resource "aws_eks_pod_identity_association" "cluster_autoscaler" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = local.cluster_autoscaler_service_account
  role_arn        = aws_iam_role.cluster_autoscaler.arn

  tags = var.tags
}

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = var.chart_versions["cluster-autoscaler"]
  namespace  = "kube-system"

  values = [yamlencode({
    cloudProvider = "aws"
    # Pods cannot reach instance metadata (hop limit 1), so set the region.
    awsRegion = data.aws_region.current.region
    autoDiscovery = {
      clusterName = var.cluster_name
    }

    # The autoscaler's minor version must match the cluster's; the chart
    # default follows the newest Kubernetes release.
    image = {
      tag = var.cluster_autoscaler_version
    }

    rbac = {
      serviceAccount = {
        create = true
        name   = local.cluster_autoscaler_service_account
      }
    }

    resources = {
      requests = { cpu = "50m", memory = "128Mi" }
      limits   = { memory = "512Mi" }
    }

    extraArgs = {
      # Treat same-sized node groups as interchangeable and keep AZs even.
      "balance-similar-node-groups" = true
      # How long a node must be underused before it is removed.
      "scale-down-unneeded-time"   = var.cluster_autoscaler_scale_down_unneeded_time
      "scale-down-delay-after-add" = var.cluster_autoscaler_scale_down_unneeded_time
      # Pods with emptyDir volumes (for example Grafana) hold only scratch
      # data, so they should not block a node from being removed.
      "skip-nodes-with-local-storage" = false
    }
  })]

  lifecycle {
    precondition {
      condition     = startswith(trimprefix(var.cluster_autoscaler_version, "v"), "${data.aws_eks_cluster.this.version}.")
      error_message = "cluster_autoscaler_version (${var.cluster_autoscaler_version}) must match the cluster's Kubernetes minor version (${data.aws_eks_cluster.this.version})."
    }
  }

  depends_on = [
    helm_release.lbc,
    aws_eks_pod_identity_association.cluster_autoscaler,
    aws_iam_role_policy_attachment.cluster_autoscaler,
  ]
}
