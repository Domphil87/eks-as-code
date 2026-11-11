# ---------------------------------------------------------------
# cert-manager: issues and renews TLS certificates stored as Kubernetes
# Secrets. Let's Encrypt proves domain ownership with DNS-01: a TXT
# record named _acme-challenge.<host>, which IAM limits it to.
# ---------------------------------------------------------------
locals {
  cert_manager_namespace       = "cert-manager"
  cert_manager_service_account = "cert-manager"
}

data "aws_iam_policy_document" "cert_manager" {
  statement {
    sid       = "ChallengeRecordsOnly"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = [data.aws_route53_zone.parent.arn]

    condition {
      test     = "ForAllValues:StringLike"
      variable = "route53:ChangeResourceRecordSetsNormalizedRecordNames"
      values   = ["_acme-challenge.${var.dns_subdomain}", "_acme-challenge.*.${var.dns_subdomain}"]
    }

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "route53:ChangeResourceRecordSetsRecordTypes"
      values   = ["TXT"]
    }
  }

  statement {
    sid       = "ReadZone"
    actions   = ["route53:ListResourceRecordSets"]
    resources = [data.aws_route53_zone.parent.arn]
  }

  statement {
    sid       = "WaitForChange"
    actions   = ["route53:GetChange"]
    resources = ["arn:${data.aws_partition.current.partition}:route53:::change/*"]
  }

  statement {
    sid       = "FindZone"
    actions   = ["route53:ListHostedZonesByName"]
    resources = ["*"] # List APIs do not support resource-level permissions.
  }
}

resource "aws_iam_policy" "cert_manager" {
  name   = "${var.cluster_name}-cert-manager"
  policy = data.aws_iam_policy_document.cert_manager.json

  tags = var.tags
}

resource "aws_iam_role" "cert_manager" {
  name               = "${var.cluster_name}-cert-manager"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cert_manager" {
  role       = aws_iam_role.cert_manager.name
  policy_arn = aws_iam_policy.cert_manager.arn
}

resource "aws_eks_pod_identity_association" "cert_manager" {
  cluster_name    = var.cluster_name
  namespace       = local.cert_manager_namespace
  service_account = local.cert_manager_service_account
  role_arn        = aws_iam_role.cert_manager.arn

  tags = var.tags
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.chart_versions["cert-manager"]
  namespace        = local.cert_manager_namespace
  create_namespace = true

  values = [yamlencode({
    # Install the Certificate/ClusterIssuer CRDs with the chart.
    crds = { enabled = true }
    serviceAccount = {
      create = true
      name   = local.cert_manager_service_account
    }
  })]

  depends_on = [
    helm_release.lbc,
    aws_eks_pod_identity_association.cert_manager,
    aws_iam_role_policy_attachment.cert_manager,
  ]
}

# ClusterIssuers are cert-manager custom resources. They are installed as
# a small local chart because Terraform cannot plan a kubernetes_manifest
# whose CRD does not exist yet (it is created by the release above).
resource "helm_release" "cluster_issuers" {
  name      = "cluster-issuers"
  chart     = "${path.module}/charts/cluster-issuers"
  namespace = local.cert_manager_namespace

  values = [yamlencode({
    dnsZone      = var.dns_subdomain
    hostedZoneID = data.aws_route53_zone.parent.zone_id
    region       = data.aws_region.current.region
  })]

  depends_on = [helm_release.cert_manager]
}
