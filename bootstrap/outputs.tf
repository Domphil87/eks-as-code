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
