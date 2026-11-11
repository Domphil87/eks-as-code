# ---------------------------------------------------------------
# External Secrets Operator: copies secrets from AWS Secrets Manager
# into Kubernetes Secrets (ExternalSecret -> Secret), so secret values
# never live in Git or Terraform.
# IAM only allows READING secrets whose names start with
# var.secrets_prefix, for example "eks-platform-as-code/dev/".
# ---------------------------------------------------------------
locals {
  eso_namespace        = "external-secrets"
  eso_service_account  = "external-secrets"
  cluster_secret_store = "aws-secrets-manager"

  secrets_arn_prefix = "arn:${data.aws_partition.current.partition}:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:${var.secrets_prefix}/"
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    sid = "ReadSecretsUnderPrefix"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds",
    ]
    # Secret ARNs end in a random 6-character suffix, hence the "*".
    resources = ["${local.secrets_arn_prefix}*"]
  }
}

resource "aws_iam_policy" "external_secrets" {
  name   = "${var.cluster_name}-external-secrets"
  policy = data.aws_iam_policy_document.external_secrets.json

  tags = var.tags
}

resource "aws_iam_role" "external_secrets" {
  name               = "${var.cluster_name}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}

resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = var.cluster_name
  namespace       = local.eso_namespace
  service_account = local.eso_service_account
  role_arn        = aws_iam_role.external_secrets.arn

  tags = var.tags
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.chart_versions["external-secrets"]
  namespace        = local.eso_namespace
  create_namespace = true

  values = [yamlencode({
    installCRDs = true
    serviceAccount = {
      create = true
      name   = local.eso_service_account
    }
  })]

  depends_on = [
    helm_release.lbc,
    aws_eks_pod_identity_association.external_secrets,
    aws_iam_role_policy_attachment.external_secrets,
  ]
}

# The cluster-wide connection to Secrets Manager. It has no credentials
# of its own: ESO uses its controller's Pod Identity role. Installed as
# a local chart for the same CRD reason as the ClusterIssuers.
resource "helm_release" "cluster_secret_store" {
  name      = "cluster-secret-store"
  chart     = "${path.module}/charts/cluster-secret-store"
  namespace = local.eso_namespace

  values = [yamlencode({
    name   = local.cluster_secret_store
    region = data.aws_region.current.region
  })]

  depends_on = [helm_release.external_secrets]
}
