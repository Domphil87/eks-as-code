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
  description = "S3 bucket holding Terraform state (used to read the cluster layer's outputs)."
  type        = string
}

variable "addon_versions" {
  description = "Pinned platform EKS add-on versions for this Kubernetes version."
  type        = map(string)
}

variable "chart_versions" {
  description = "Pinned Helm chart versions for platform components."
  type        = map(string)
}

variable "parent_domain" {
  description = "Existing public Route 53 hosted zone."
  type        = string
}

variable "dns_subdomain" {
  description = "Subdomain owned by this environment (application host names live under it)."
  type        = string
}

variable "create_demo_secret" {
  description = "Create the ESO demo secret in Secrets Manager."
  type        = bool
}

variable "secret_recovery_window_days" {
  description = "Recovery window for deleted secrets (0 = delete immediately)."
  type        = number
}

variable "prometheus_retention" {
  description = "How long Prometheus keeps metrics."
  type        = string
}

variable "prometheus_storage_gib" {
  description = "Prometheus volume size in GiB."
  type        = number
}

variable "container_log_retention_days" {
  description = "CloudWatch retention for container logs."
  type        = number
}

variable "cluster_autoscaler_version" {
  description = "Cluster Autoscaler image tag (minor must match Kubernetes)."
  type        = string
}

variable "cluster_autoscaler_scale_down_unneeded_time" {
  description = "Idle time before Cluster Autoscaler removes a node."
  type        = string
}
