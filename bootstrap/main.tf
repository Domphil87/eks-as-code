# Looks up the AWS account that your current credentials belong to.
# Using it in the bucket name avoids hard-coding the account ID and makes
# the (globally unique) bucket name very unlikely to clash with anyone else.
data "aws_caller_identity" "current" {}

locals {
  # Example: eks-platform-as-code-tfstate-123456789012-us-east-1
  state_bucket_name = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
}

# ---------------------------------------------------------------
# S3 bucket that stores Terraform state for every layer and environment
# ---------------------------------------------------------------
resource "aws_s3_bucket" "tfstate" {
  # Accepted risks, documented in bootstrap/README.md ("Checkov results").
  # Remove a line to make Checkov enforce that check again.
  #checkov:skip=CKV_AWS_145:SSE-S3 chosen over a KMS key to avoid KMS cost; revisit before production
  #checkov:skip=CKV_AWS_18:Access logging needs a second log bucket; deferred for this lab, CloudTrail records bucket-level API calls
  #checkov:skip=CKV_AWS_144:Cross-region replication doubles storage cost; state is protected by versioning instead
  #checkov:skip=CKV2_AWS_62:Event notifications are not needed for a Terraform state bucket
  bucket = local.state_bucket_name

  # Never let `terraform destroy` empty the bucket: it holds the only record
  # of what Terraform has built.
  force_destroy = false

  lifecycle {
    # Terraform refuses any plan that would delete this bucket. To remove it
    # during final teardown, you must deliberately edit this line first.
    prevent_destroy = true

    precondition {
      condition     = length(local.state_bucket_name) <= 63
      error_message = "S3 bucket names are limited to 63 characters; shorten var.project."
    }
  }
}

# Every write keeps the previous version, so a corrupted or accidentally
# deleted state file can be restored.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt every object at rest with SSE-S3 (AES-256, keys managed by S3).
# No extra cost. See README.md for the SSE-S3 vs. KMS trade-off.
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block every form of public access, even if someone later adds a public
# ACL or bucket policy by mistake.
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Disable ACLs entirely: access is controlled only by IAM and the bucket policy.
resource "aws_s3_bucket_ownership_controls" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Housekeeping so versioning does not grow storage forever.
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "state-history-retention"
    status = "Enabled"

    # Empty filter = apply to every object in the bucket.
    filter {}

    # Old versions of state files are deleted after the retention period.
    noncurrent_version_expiration {
      noncurrent_days = var.state_noncurrent_version_retention_days
    }

    # Clean up "delete markers" left behind once all old versions are gone.
    expiration {
      expired_object_delete_marker = true
    }

    # Remove half-finished uploads that would otherwise be billed silently.
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # Lifecycle rules on a versioned bucket must be applied after versioning.
  depends_on = [aws_s3_bucket_versioning.tfstate]
}

# Bucket policy: refuse any request that is not encrypted in transit
# (plain HTTP) or that uses an outdated TLS version.
data "aws_iam_policy_document" "tfstate" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [
      aws_s3_bucket.tfstate.arn,
      "${aws_s3_bucket.tfstate.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid     = "DenyOutdatedTLS"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [
      aws_s3_bucket.tfstate.arn,
      "${aws_s3_bucket.tfstate.arn}/*",
    ]

    condition {
      test     = "NumericLessThan"
      variable = "s3:TlsVersion"
      values   = ["1.2"]
    }
  }
}

resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  policy = data.aws_iam_policy_document.tfstate.json

  # Apply the public access block first so the two settings never conflict.
  depends_on = [aws_s3_bucket_public_access_block.tfstate]
}
