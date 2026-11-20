# ---------------------------------------------------------------
# CodeBuild-hosted GitHub Actions runner in the private subnets
# (ADR 0003). A workflow job with
#   runs-on: codebuild-<name>-${{ github.run_id }}-${{ github.run_attempt }}
# starts a CodeBuild build that registers itself as a one-off runner,
# runs that single job inside the VPC, and is gone afterwards. Billed
# per build minute; nothing runs while idle.
# ---------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
  partition  = data.aws_partition.current.partition
  log_group  = "/aws/codebuild/${var.name}"
}

resource "aws_security_group" "runner" {
  name        = var.name
  description = "CodeBuild GitHub Actions runner: outbound only"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = var.name })
}

# Outbound HTTPS to GitHub, AWS APIs, the EKS API, Terraform/Helm
# registries (through the NAT gateway or the VPC).
resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.runner.id
  description       = "HTTPS to GitHub, AWS APIs, the EKS API and registries"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# DNS through the VPC resolver.
resource "aws_vpc_security_group_egress_rule" "dns_udp" {
  security_group_id = aws_security_group.runner.id
  description       = "DNS to the VPC resolver"
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
}

resource "aws_vpc_security_group_egress_rule" "dns_tcp" {
  security_group_id = aws_security_group.runner.id
  description       = "DNS over TCP to the VPC resolver"
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "tcp"
  from_port         = 53
  to_port           = 53
}

resource "aws_cloudwatch_log_group" "runner" {
  #checkov:skip=CKV_AWS_158:Default CloudWatch encryption; a customer KMS key is not used to avoid cost
  #checkov:skip=CKV_AWS_338:Short retention for build logs in a lab; the job logs also live in GitHub Actions
  name              = local.log_group
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# ---------------------------------------------------------------
# Service role of the build itself. It only needs to run in the VPC,
# write its logs and talk to GitHub; the job obtains its AWS rights
# separately, from the GitHub OIDC roles (plan/apply).
# ---------------------------------------------------------------
data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${local.partition}:codebuild:${local.region}:${local.account_id}:project/${var.name}"]
    }
  }
}

resource "aws_iam_role" "runner" {
  name               = var.name
  description        = "CodeBuild service role for the GitHub Actions runner ${var.name}"
  assume_role_policy = data.aws_iam_policy_document.trust.json

  tags = var.tags
}

data "aws_iam_policy_document" "runner" {
  statement {
    sid       = "Logs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.runner.arn}:*"]
  }

  # CodeBuild creates and removes an ENI in the private subnet per build.
  # These EC2 describe/create calls do not support resource scoping.
  statement {
    sid = "VpcNetworking"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeDhcpOptions",
      "ec2:DescribeVpcs",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "VpcNetworkInterfacePermission"
    actions   = ["ec2:CreateNetworkInterfacePermission"]
    resources = ["arn:${local.partition}:ec2:${local.region}:${local.account_id}:network-interface/*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:AuthorizedService"
      values   = ["codebuild.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "ec2:Subnet"
      values   = [for id in var.subnet_ids : "arn:${local.partition}:ec2:${local.region}:${local.account_id}:subnet/${id}"]
    }
  }

  statement {
    sid       = "GitHubConnection"
    actions   = ["codeconnections:UseConnection", "codeconnections:GetConnectionToken", "codeconnections:GetConnection"]
    resources = [var.github_connection_arn]
  }
}

resource "aws_iam_role_policy" "runner" {
  #checkov:skip=CKV_AWS_355:EC2 network-interface describe/create calls used by CodeBuild in a VPC do not support resource-level scoping
  #checkov:skip=CKV_AWS_290:Same as CKV_AWS_355
  name   = "codebuild-runner"
  role   = aws_iam_role.runner.id
  policy = data.aws_iam_policy_document.runner.json
}

# ---------------------------------------------------------------
# The runner project and its webhook.
# ---------------------------------------------------------------
resource "aws_codebuild_project" "runner" {
  #checkov:skip=CKV_AWS_147:Build artifacts are not produced (runner project); default AWS-managed encryption is used for logs and cache
  name                   = var.name
  description            = "GitHub Actions runner in the VPC for ${var.github_repository_url}"
  service_role           = aws_iam_role.runner.arn
  build_timeout          = var.build_timeout_minutes
  queued_timeout         = 60
  concurrent_build_limit = var.concurrent_build_limit

  source {
    type     = "GITHUB"
    location = var.github_repository_url
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    type         = "LINUX_CONTAINER"
    compute_type = var.compute_type
    image        = var.image
    # Jobs need no Docker daemon, so the build container is not privileged.
    privileged_mode = false
  }

  vpc_config {
    vpc_id             = var.vpc_id
    subnets            = var.subnet_ids
    security_group_ids = [aws_security_group.runner.id]
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.runner.name
      status     = "ENABLED"
    }
  }

  tags = var.tags

  depends_on = [aws_iam_role_policy.runner]
}

# Only queued Actions jobs, only from the listed workflows, and only when
# the run was triggered by the repository owner. The repository is
# public: without the actor filter, anyone's pull request could run code
# inside the VPC.
resource "aws_codebuild_webhook" "runner" {
  project_name = aws_codebuild_project.runner.name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "WORKFLOW_JOB_QUEUED"
    }

    filter {
      type    = "ACTOR_ACCOUNT_ID"
      pattern = "^(${join("|", var.allowed_actor_ids)})$"
    }

    filter {
      type    = "WORKFLOW_NAME"
      pattern = "^(${join("|", var.allowed_workflow_names)})$"
    }
  }
}
