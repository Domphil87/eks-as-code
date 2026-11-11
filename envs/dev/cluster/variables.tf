variable "aws_region" {
  description = "AWS region for this environment."
  type        = string
}

variable "project" {
  description = "Project name, used in resource names and the Project tag."
  type        = string
}

variable "environment" {
  description = "Environment name, for example dev or staging."
  type        = string
}

variable "owner" {
  description = "Owner tag value."
  type        = string
}

variable "cost_center" {
  description = "CostCenter tag value."
  type        = string
}

variable "state_bucket" {
  description = "S3 bucket holding Terraform state (used to read the network layer's outputs)."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes minor version for the cluster."
  type        = string
}

variable "addon_versions" {
  description = "Pinned core add-on versions for this Kubernetes version."
  type        = map(string)
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint. Set in the git-ignored admin-access.auto.tfvars."
  type        = list(string)
}

variable "cluster_admin_principal_arns" {
  description = "IAM principals that get cluster-admin."
  type        = list(string)
}

variable "enabled_log_types" {
  description = "Control-plane log types to send to CloudWatch."
  type        = list(string)
}

variable "log_retention_days" {
  description = "CloudWatch retention for control-plane logs."
  type        = number
}

variable "node_instance_types" {
  description = "Node instance types (same vCPU/memory size)."
  type        = list(string)
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT."
  type        = string
}

variable "node_min_size" {
  description = "Minimum node count."
  type        = number
}

variable "node_desired_size" {
  description = "Initial node count."
  type        = number
}

variable "node_max_size" {
  description = "Maximum node count."
  type        = number
}
