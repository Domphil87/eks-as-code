# ---------------------------------------------------------------
# ExternalDNS: creates Route 53 records for Ingress/Service host names.
# IAM only allows changes to A/AAAA/CNAME/TXT records under
# var.dns_subdomain, so it cannot touch any other record in the zone.
# ---------------------------------------------------------------
locals {
  external_dns_namespace       = "external-dns"
  external_dns_service_account = "external-dns"
}

data "aws_iam_policy_document" "external_dns" {
  statement {
    sid       = "ChangeRecordsUnderSubdomainOnly"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = [data.aws_route53_zone.parent.arn]

    condition {
      test     = "ForAllValues:StringLike"
      variable = "route53:ChangeResourceRecordSetsNormalizedRecordNames"
      values   = [var.dns_subdomain, "*.${var.dns_subdomain}"]
    }

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "route53:ChangeResourceRecordSetsRecordTypes"
      values   = ["A", "AAAA", "CNAME", "TXT"]
    }
  }

  statement {
    sid = "ReadZone"
    actions = [
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource",
      "route53:ListTagsForResources",
    ]
    resources = [data.aws_route53_zone.parent.arn]
  }

  statement {
    sid       = "FindZones"
    actions   = ["route53:ListHostedZones"]
    resources = ["*"] # List APIs do not support resource-level permissions.
  }
}

resource "aws_iam_policy" "external_dns" {
  name   = "${var.cluster_name}-external-dns"
  policy = data.aws_iam_policy_document.external_dns.json

  tags = var.tags
}

resource "aws_iam_role" "external_dns" {
  name               = "${var.cluster_name}-external-dns"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns.arn
}

resource "aws_eks_pod_identity_association" "external_dns" {
  cluster_name    = var.cluster_name
  namespace       = local.external_dns_namespace
  service_account = local.external_dns_service_account
  role_arn        = aws_iam_role.external_dns.arn

  tags = var.tags
}

resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  chart            = "external-dns"
  version          = var.chart_versions["external-dns"]
  namespace        = local.external_dns_namespace
  create_namespace = true

  values = [yamlencode({
    provider = { name = "aws" }
    # No instance metadata for pods, so the SDK needs the region here.
    env = [{ name = "AWS_DEFAULT_REGION", value = data.aws_region.current.region }]

    serviceAccount = {
      create = true
      name   = local.external_dns_service_account
    }

    sources       = ["ingress", "service"]
    domainFilters = [var.dns_subdomain]
    extraArgs     = ["--zone-id-filter=${data.aws_route53_zone.parent.zone_id}"]

    # sync: also deletes records when the Ingress is deleted, but only
    # records this cluster owns (marked by TXT records with this owner ID).
    policy     = "sync"
    registry   = "txt"
    txtOwnerId = var.cluster_name
  })]

  # The Load Balancer Controller's webhooks must be ready before other
  # charts create Services.
  depends_on = [
    helm_release.lbc,
    aws_eks_pod_identity_association.external_dns,
    aws_iam_role_policy_attachment.external_dns,
  ]
}
