# ---------------------------------------------------------------
# GitHub Actions access to AWS (Milestone 6). No stored AWS keys: a
# workflow exchanges its GitHub OIDC token for short-lived credentials
# of one of these roles. The trust policies decide WHICH workflow runs
# may do that.
#
# The roles live in bootstrap (never torn down) and are named outside
# the "<project>-<env>-*" pattern that the apply role may manage, so CI
# cannot edit its own permissions.
# ---------------------------------------------------------------

# The account already has GitHub's OIDC provider (shared with other
# projects), so it is only looked up here, never created or changed.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  github_oidc_sub = "token.actions.githubusercontent.com:sub"
  github_oidc_aud = "token.actions.githubusercontent.com:aud"
  ci_role_prefix  = "github-actions-${var.project}"

  # IAM names the layers create, for example eks-platform-as-code-dev-node.
  managed_iam_name_patterns = [for env in var.ci_environments : "${var.project}-${env}-*"]
}

# ---------------------------------------------------------------
# Plan role: read-only. Pull requests from this repository (not forks:
# GitHub gives fork PRs no OIDC token) and pushes to main.
# ---------------------------------------------------------------
data "aws_iam_policy_document" "ci_plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = local.github_oidc_aud
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = local.github_oidc_sub
      values = [
        "repo:${var.github_repository}:pull_request",
        "repo:${var.github_repository}:ref:refs/heads/main",
      ]
    }
  }
}

resource "aws_iam_role" "ci_plan" {
  name                 = "${local.ci_role_prefix}-plan"
  description          = "GitHub Actions: terraform plan (read-only) for ${var.github_repository}"
  assume_role_policy   = data.aws_iam_policy_document.ci_plan_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "ci_plan_readonly" {
  role       = aws_iam_role.ci_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Plan takes the state lock: write and delete only the .tflock objects.
data "aws_iam_policy_document" "ci_plan_state_lock" {
  statement {
    sid       = "StateLockFiles"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.tfstate.arn}/envs/*.tflock"]
  }
}

resource "aws_iam_role_policy" "ci_plan_state_lock" {
  name   = "terraform-state-lock"
  role   = aws_iam_role.ci_plan.id
  policy = data.aws_iam_policy_document.ci_plan_state_lock.json
}

# ---------------------------------------------------------------
# Apply role: only workflow jobs that run in a protected GitHub
# environment (dev, staging) may assume it, and those environments
# require your approval before a job starts.
# ---------------------------------------------------------------
data "aws_iam_policy_document" "ci_apply_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = local.github_oidc_aud
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = local.github_oidc_sub
      values   = [for env in var.ci_environments : "repo:${var.github_repository}:environment:${env}"]
    }
  }
}

resource "aws_iam_role" "ci_apply" {
  name                 = "${local.ci_role_prefix}-apply"
  description          = "GitHub Actions: terraform apply/destroy for ${var.github_repository} (protected environments only)"
  assume_role_policy   = data.aws_iam_policy_document.ci_apply_trust.json
  max_session_duration = 7200 # cluster create + platform add-ons can exceed an hour
}

# Everything except IAM, Organizations and Account management.
resource "aws_iam_role_policy_attachment" "ci_apply_poweruser" {
  #checkov:skip=CKV_AWS_274:Broad rights are needed to create a whole environment; the role is limited by its trust policy to approved runs in protected environments
  role       = aws_iam_role.ci_apply.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

data "aws_iam_policy_document" "ci_apply_iam" {
  #checkov:skip=CKV_AWS_356:Only the read-only iam:Get*/List* statement uses "*" (plans read IAM across the account); every write is scoped to ARNs
  # IAM only for the roles, policies and instance profiles the layers
  # create (named <project>-<env>-*).
  statement {
    sid     = "ManageProjectIam"
    actions = ["iam:*"]
    resources = flatten([
      for p in local.managed_iam_name_patterns : [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${p}",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${p}",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/${p}",
      ]
    ])
  }

  statement {
    sid = "ReadIam"
    actions = [
      "iam:Get*",
      "iam:List*",
    ]
    resources = ["*"]
  }

  # Service-linked roles that EKS, node groups, ELB and Spot create on
  # first use in an account.
  statement {
    sid       = "ServiceLinkedRoles"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/*"]

    condition {
      test     = "StringLike"
      variable = "iam:AWSServiceName"
      values = [
        "eks.amazonaws.com",
        "eks-nodegroup.amazonaws.com",
        "elasticloadbalancing.amazonaws.com",
        "spot.amazonaws.com",
        "autoscaling.amazonaws.com",
        "elasticfilesystem.amazonaws.com",
      ]
    }
  }

  # The state bucket must survive any CI mistake.
  statement {
    sid    = "ProtectStateBucket"
    effect = "Deny"
    actions = [
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
      "s3:PutBucketPolicy",
      "s3:PutBucketVersioning",
      "s3:PutLifecycleConfiguration",
      "s3:PutEncryptionConfiguration",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketOwnershipControls",
    ]
    resources = [aws_s3_bucket.tfstate.arn]
  }
}

resource "aws_iam_role_policy" "ci_apply_iam" {
  name   = "project-iam"
  role   = aws_iam_role.ci_apply.id
  policy = data.aws_iam_policy_document.ci_apply_iam.json
}

# ---------------------------------------------------------------
# GitHub connection for the CodeBuild-hosted Actions runner (6b).
# Created as PENDING; finish it once in the AWS console (Developer
# Tools > Settings > Connections > Update pending connection), which
# installs the "AWS Connector for GitHub" app on the repository.
# ---------------------------------------------------------------
resource "aws_codeconnections_connection" "github" {
  name          = "${var.project}-github"
  provider_type = "GitHub"
}
