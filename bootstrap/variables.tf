# ---------------------------------------------------------------
# General / tagging
# ---------------------------------------------------------------
variable "aws_region" {
  description = "AWS region for the Terraform state bucket."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]$", var.aws_region))
    error_message = "aws_region must look like a real region code, for example us-east-1."
  }
}

variable "project" {
  description = "Project name. Used in resource names and the Project tag."
  type        = string

  validation {
    # Must be usable inside an S3 bucket name: lowercase, digits, hyphens.
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.project))
    error_message = "project must be 3-32 characters of lowercase letters, digits and hyphens."
  }
}

variable "environment" {
  description = "Environment tag value. Bootstrap resources are shared by every environment."
  type        = string
  default     = "shared"
}

variable "owner" {
  description = "Owner tag value: the person or team responsible for these resources."
  type        = string
}

variable "cost_center" {
  description = "CostCenter tag value used for cost reporting."
  type        = string
}

# ---------------------------------------------------------------
# State bucket
# ---------------------------------------------------------------
variable "state_noncurrent_version_retention_days" {
  description = "Days to keep old (noncurrent) versions of state files before S3 deletes them."
  type        = number
  default     = 90

  validation {
    condition     = var.state_noncurrent_version_retention_days >= 30
    error_message = "Keep at least 30 days of state history so mistakes can be recovered."
  }
}

# ---------------------------------------------------------------
# Budget alerts
# ---------------------------------------------------------------
variable "budget_limit_usd" {
  description = "Monthly budget amount in USD. Alerts are percentages of this value."
  type        = number

  validation {
    condition     = var.budget_limit_usd > 0
    error_message = "budget_limit_usd must be greater than 0."
  }
}

variable "budget_alert_emails" {
  description = "Email addresses that receive budget alerts. Kept in the git-ignored terraform.tfvars."
  type        = list(string)

  validation {
    condition     = length(var.budget_alert_emails) > 0 && alltrue([for e in var.budget_alert_emails : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", e))])
    error_message = "Provide at least one valid email address."
  }
}

variable "budget_actual_alert_thresholds" {
  description = "Percentages of the budget that trigger an alert once ACTUAL spend passes them."
  type        = list(number)
  default     = [50, 80, 100]
}

variable "budget_forecast_alert_threshold" {
  description = "Percentage of the budget that triggers an alert when FORECASTED month-end spend passes it."
  type        = number
  default     = 100
}

variable "budget_filter_by_project_tag" {
  description = "If true, the budget only counts costs tagged Project=<project>. Requires the Project cost allocation tag to be activated in the Billing console (see README)."
  type        = bool
  default     = true
}
