# ---------------------------------------------------------------
# AWS Load Balancer Controller: turns Kubernetes Ingress objects into
# ALBs and Services of type LoadBalancer into NLBs.
# ---------------------------------------------------------------
data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_region" "current" {}

locals {
  lbc_namespace       = "kube-system"
  lbc_service_account = "aws-load-balancer-controller"
}

# The official policy published with this controller version, stored
# unmodified in the repo so changes show up in code review. Update the
# file together with the chart version.
resource "aws_iam_policy" "lbc" {
  name        = "${var.cluster_name}-aws-load-balancer-controller"
  description = "AWS Load Balancer Controller ${var.chart_versions["aws-load-balancer-controller"]} (upstream docs/install/iam_policy.json)"
  policy      = file("${path.module}/policies/aws-load-balancer-controller-v${var.chart_versions["aws-load-balancer-controller"]}.json")

  tags = var.tags
}

resource "aws_iam_role" "lbc" {
  name               = "${var.cluster_name}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lbc" {
  role       = aws_iam_role.lbc.name
  policy_arn = aws_iam_policy.lbc.arn
}

# Helm-installed components need an explicit association (EKS managed
# add-ons create theirs through pod_identity_association instead).
resource "aws_eks_pod_identity_association" "lbc" {
  cluster_name    = var.cluster_name
  namespace       = local.lbc_namespace
  service_account = local.lbc_service_account
  role_arn        = aws_iam_role.lbc.arn

  tags = var.tags
}

resource "helm_release" "lbc" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.chart_versions["aws-load-balancer-controller"]
  namespace  = local.lbc_namespace

  values = [yamlencode({
    clusterName = var.cluster_name
    # Set explicitly: pods cannot reach instance metadata (hop limit 1),
    # so the controller cannot discover these by itself.
    region = data.aws_region.current.region
    vpcId  = data.aws_eks_cluster.this.vpc_config[0].vpc_id

    replicaCount = 2
    serviceAccount = {
      create = true
      name   = local.lbc_service_account
    }
    # Send traffic straight to pod IPs instead of through node ports.
    defaultTargetType = "ip"
  })]

  depends_on = [
    aws_eks_pod_identity_association.lbc,
    aws_iam_role_policy_attachment.lbc,
  ]
}
