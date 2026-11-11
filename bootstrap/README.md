# Bootstrap: Terraform state bucket and budget alert

Run this folder **once, by hand, from your laptop**, before any other layer.

Every other Terraform configuration in this repo stores its state in an S3
bucket. That bucket must already exist before those configurations can run,
so it cannot create itself through a remote backend. Bootstrap solves this:
it starts with **local state**, creates the bucket, and (optionally) moves its
own state into the bucket afterwards.

## What it creates

| Resource | Purpose | Cost |
|---|---|---|
| `aws_s3_bucket.tfstate` | Stores state for every layer/environment | A few cents/month at most |
| `aws_s3_bucket_versioning` | Keeps every previous state version, so mistakes can be undone | Included above |
| `aws_s3_bucket_server_side_encryption_configuration` | SSE-S3 (AES-256) encryption at rest | Free |
| `aws_s3_bucket_public_access_block` | Blocks all public access | Free |
| `aws_s3_bucket_ownership_controls` | Disables ACLs (IAM and bucket policy only) | Free |
| `aws_s3_bucket_lifecycle_configuration` | Deletes old versions after 90 days; cleans up failed uploads | Free |
| `aws_s3_bucket_policy` | Denies plain-HTTP and TLS < 1.2 requests | Free |
| `aws_budgets_budget.project` | Email alerts at 50/80/100% actual and 100% forecasted spend | Free (the account's 2nd budget) |

There is **no DynamoDB table**: Terraform 1.10+ locks state with a small
`.tflock` object in the bucket itself (`use_lockfile = true`).

## Prerequisites

- Terraform 1.15.x or later 1.x (`terraform version`)
- AWS CLI v2, signed in to the target account (`aws sts get-caller-identity`)
- `terraform.tfvars` created from `terraform.tfvars.example` (git-ignored)

## Commands (PowerShell, from this folder)

```powershell
cd C:\Users\domin\eks-platform-as-code\bootstrap

terraform fmt -check          # formatting
terraform init                # download the pinned AWS provider
terraform validate            # syntax and type checks
terraform plan -out=bootstrap.tfplan   # preview, changes NOTHING

# Only after reviewing the plan:
terraform apply bootstrap.tfplan
```

Expected plan: **8 to add, 0 to change, 0 to destroy**.

## Verification after apply

```powershell
terraform output
$bucket = terraform output -raw state_bucket_name
aws s3api get-bucket-versioning          --bucket $bucket   # Status: Enabled
aws s3api get-bucket-encryption          --bucket $bucket   # SSEAlgorithm: AES256
aws s3api get-public-access-block        --bucket $bucket   # all four: true
aws s3api get-bucket-ownership-controls  --bucket $bucket   # BucketOwnerEnforced
aws s3api get-bucket-policy --bucket $bucket --query Policy --output text
aws budgets describe-budget --account-id (aws sts get-caller-identity --query Account --output text) --budget-name eks-platform-as-code-monthly
```

## Activate the `Project` cost allocation tag (one-time, manual, free)

The budget only counts costs tagged `Project=eks-platform-as-code`. AWS
ignores user tags for billing until you **activate** them:

1. Wait about 24 hours after the first apply, so AWS has seen the tag on the bucket.
2. Billing and Cost Management console → **Cost allocation tags** →
   **User-defined** → select `Project` → **Activate**.
3. Activation takes up to 24 hours more. It only applies to costs from that point on.

Until this is done, the project budget shows **$0**. Your existing
account-wide `billing-budget` is the safety net in the meantime. Some charges
(for example, some data transfer) are never tagged, so the account-wide
budget remains the true total.

If you prefer an account-wide budget instead, set
`budget_filter_by_project_tag = false`.

## Migrating bootstrap state into S3 (optional, recommended)

After the first apply, the bootstrap state is in `terraform.tfstate` on your
laptop (git-ignored). If your laptop is lost, that record is lost too. To
store it in the bucket it created:

1. Create `backend.tf` in this folder (use the bucket name from `terraform output`):

   ```hcl
   terraform {
     backend "s3" {
       bucket       = "<state_bucket_name>"
       key          = "bootstrap/terraform.tfstate"
       region       = "us-east-1"
       encrypt      = true
       use_lockfile = true
     }
   }
   ```

2. Run `terraform init -migrate-state` and answer `yes`.
3. Run `terraform plan`. It should report **No changes**. Then delete the local
   `terraform.tfstate*` files.

At final teardown, reverse this: remove `backend.tf`, then run
`terraform init -migrate-state` to bring the state back locally before
destroying the bucket.

## Encryption choice: SSE-S3 vs. a KMS customer-managed key

| | SSE-S3 (chosen) | SSE-KMS with a customer-managed key |
|---|---|---|
| Encryption at rest | AES-256 | AES-256 |
| Who controls the key | AWS S3, invisibly | You: key policy, rotation, disable/delete |
| Extra access control | No. Anyone with `s3:GetObject` can read the state | Yes. A reader also needs `kms:Decrypt`, a second, independent permission |
| Audit | S3 access only | Every decrypt is logged in CloudTrail |
| Cost | Free | About $1/month per key, plus $0.03 per 10,000 requests |
| Complexity | None | Key policy and IAM grants for every CI role |

For a single-person lab, SSE-S3 plus a strict bucket policy and least-privilege
IAM is a reasonable choice. For production, a customer-managed key is
recommended. State can contain sensitive values, and the extra `kms:Decrypt`
gate limits damage if an S3 permission is too broad. Switching later is a
small change.

## Checkov results

26 checks pass. 4 are intentionally skipped, with reasons recorded in
`main.tf`:

| Check | Why skipped |
|---|---|
| CKV_AWS_145: KMS encryption | SSE-S3 chosen for cost (see above) |
| CKV_AWS_18: access logging | Needs a second bucket; deferred for the lab |
| CKV_AWS_144: cross-region replication | Doubles storage cost; versioning protects state |
| CKV2_AWS_62: event notifications | Not useful for a state bucket |

## Teardown

The bucket has `prevent_destroy = true`, so Terraform refuses to delete it.
This is intentional: it must outlive every other layer. Final teardown steps
are documented in the root README.
