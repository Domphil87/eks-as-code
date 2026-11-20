output "state_bucket_name" {
  description = "Name of the S3 bucket that stores Terraform state. Used in every layer's backend block."
  value       = aws_s3_bucket.tfstate.bucket
}

output "state_bucket_arn" {
  description = "ARN of the state bucket. Used later when writing IAM policies for CI roles."
  value       = aws_s3_bucket.tfstate.arn
}

output "aws_region" {
  description = "Region of the state bucket."
  value       = var.aws_region
}

output "budget_name" {
  description = "Name of the AWS Budget that sends cost alerts."
  value       = aws_budgets_budget.project.name
}

output "backend_config_example" {
  description = "Copy-paste backend block for a layer. Replace <env>/<layer>."
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket       = "${aws_s3_bucket.tfstate.bucket}"
        key          = "envs/<env>/<layer>/terraform.tfstate"
        region       = "${var.aws_region}"
        encrypt      = true
        use_lockfile = true
      }
    }
  EOT
}

output "ci_plan_role_arn" {
  description = "Role for terraform plan in GitHub Actions. Set as the repository variable AWS_PLAN_ROLE_ARN."
  value       = aws_iam_role.ci_plan.arn
}

output "ci_apply_role_arn" {
  description = "Role for terraform apply in protected GitHub environments. Set as the repository variable AWS_APPLY_ROLE_ARN."
  value       = aws_iam_role.ci_apply.arn
}

output "github_connection_arn" {
  description = "CodeConnections connection to GitHub, used by the CodeBuild-hosted runner."
  value       = aws_codeconnections_connection.github.arn
}

output "github_connection_status" {
  description = "PENDING until completed once in the AWS console; must be AVAILABLE for the CodeBuild runner."
  value       = aws_codeconnections_connection.github.connection_status
}
