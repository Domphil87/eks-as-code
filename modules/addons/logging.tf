# ---------------------------------------------------------------
# Fluent Bit (EKS community add-on): ships every container's logs to
# CloudWatch Logs, one stream per namespace/pod/container.
# ---------------------------------------------------------------
locals {
  # Fixed by the add-on (AWS docs, "Community add-ons").
  fluent_bit_namespace       = "fluent-bit"
  fluent_bit_service_account = "fluent-bit"
}

# Created by Terraform (not by Fluent Bit) so it has a retention period
# and is deleted on destroy.
resource "aws_cloudwatch_log_group" "containers" {
  #checkov:skip=CKV_AWS_158:Logs use CloudWatch default encryption; no KMS key, consistent with the project's no-KMS cost decision
  #checkov:skip=CKV_AWS_338:Dev keeps a short retention to limit cost; production would keep 1 year
  name              = "/aws/eks/${var.cluster_name}/containers"
  retention_in_days = var.container_log_retention_days

  tags = var.tags
}

data "aws_iam_policy_document" "fluent_bit" {
  statement {
    sid = "WriteToContainerLogGroupOnly"
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    # The group itself and every log stream in it.
    resources = [
      aws_cloudwatch_log_group.containers.arn,
      "${aws_cloudwatch_log_group.containers.arn}:*",
    ]
  }
}

resource "aws_iam_policy" "fluent_bit" {
  name   = "${var.cluster_name}-fluent-bit"
  policy = data.aws_iam_policy_document.fluent_bit.json

  tags = var.tags
}

resource "aws_iam_role" "fluent_bit" {
  name               = "${var.cluster_name}-fluent-bit"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "fluent_bit" {
  role       = aws_iam_role.fluent_bit.name
  policy_arn = aws_iam_policy.fluent_bit.arn
}

# The add-on declares no Pod Identity configuration, so the association
# is created separately (Fluent Bit 5.x reads Pod Identity credentials).
resource "aws_eks_pod_identity_association" "fluent_bit" {
  cluster_name    = var.cluster_name
  namespace       = local.fluent_bit_namespace
  service_account = local.fluent_bit_service_account
  role_arn        = aws_iam_role.fluent_bit.arn

  tags = var.tags
}

resource "aws_eks_addon" "fluent_bit" {
  cluster_name  = var.cluster_name
  addon_name    = "fluent-bit"
  addon_version = var.addon_versions["fluent-bit"]

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # Same keys as the upstream fluent-bit Helm chart's "config" section.
  configuration_values = jsonencode({
    config = {
      inputs  = <<-EOT
        [INPUT]
            Name              tail
            Path              /var/log/containers/*.log
            multiline.parser  docker, cri
            Tag               kube.*
            Mem_Buf_Limit     5MB
            Skip_Long_Lines   On
      EOT
      filters = <<-EOT
        [FILTER]
            Name                kubernetes
            Match               kube.*
            Merge_Log           On
            Keep_Log            Off
            Labels              Off
            Annotations         Off
            K8S-Logging.Parser  On
            K8S-Logging.Exclude On
      EOT
      outputs = <<-EOT
        [OUTPUT]
            Name                cloudwatch_logs
            Match               kube.*
            region              ${data.aws_region.current.region}
            log_group_name      ${aws_cloudwatch_log_group.containers.name}
            auto_create_group   Off
            log_stream_prefix   unknown.
            log_stream_template $kubernetes['namespace_name'].$kubernetes['pod_name'].$kubernetes['container_name']
      EOT
    }
  })

  tags = var.tags

  # Credentials must be in place before the DaemonSet starts.
  depends_on = [
    aws_eks_pod_identity_association.fluent_bit,
    aws_iam_role_policy_attachment.fluent_bit,
  ]
}
