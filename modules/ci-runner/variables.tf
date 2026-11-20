variable "name" {
  description = "Name of the CodeBuild project; also the runs-on prefix (codebuild-<name>-...). Must match the <project>-<env>-* pattern the CI apply role may manage."
  type        = string
}

variable "vpc_id" {
  description = "VPC the runner builds run in."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR, for DNS egress to the VPC resolver."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the build ENIs (outbound through the NAT gateway)."
  type        = list(string)
}

variable "github_repository_url" {
  description = "HTTPS URL of the GitHub repository whose jobs the runner takes."
  type        = string
}

variable "github_connection_arn" {
  description = "CodeConnections connection to GitHub (bootstrap), status AVAILABLE."
  type        = string
}

variable "allowed_actor_ids" {
  description = "Numeric GitHub account IDs whose workflow runs may use the runner."
  type        = list(string)

  validation {
    condition     = length(var.allowed_actor_ids) > 0 && alltrue([for id in var.allowed_actor_ids : can(regex("^[0-9]+$", id))])
    error_message = "List at least one numeric GitHub account ID."
  }
}

variable "allowed_workflow_names" {
  description = "Workflow names (the name: field) whose jobs may use the runner."
  type        = list(string)
}

variable "compute_type" {
  description = "CodeBuild compute type."
  type        = string
  default     = "BUILD_GENERAL1_MEDIUM"
}

variable "image" {
  description = "CodeBuild image for the runner (includes the AWS CLI used by aws eks get-token)."
  type        = string
  default     = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
}

variable "build_timeout_minutes" {
  description = "Maximum duration of one job."
  type        = number
  default     = 120
}

variable "concurrent_build_limit" {
  description = "Maximum parallel runner builds."
  type        = number
  default     = 3
}

variable "log_retention_days" {
  description = "CloudWatch retention for runner build logs."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Extra tags for resources that do not inherit provider default tags."
  type        = map(string)
  default     = {}
}
