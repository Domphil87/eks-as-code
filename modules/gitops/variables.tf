variable "argocd_chart_version" {
  description = "Pinned argo-cd Helm chart version (https://argoproj.github.io/argo-helm)."
  type        = string
}

variable "hostname" {
  description = "Public host name for the Argo CD UI, for example argocd.dev.example.com. Must be covered by the ACM certificate."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.hostname))
    error_message = "hostname must be a lower-case DNS name."
  }
}

variable "acm_certificate_arn" {
  description = "ACM certificate for the ALB HTTPS listener (the environment's wildcard)."
  type        = string
}

variable "allowed_cidrs" {
  description = "Source CIDRs allowed to reach the ALB. Keep this to admin IPs: the Argo CD UI is an admin tool."
  type        = list(string)

  validation {
    condition     = length(var.allowed_cidrs) > 0 && alltrue([for c in var.allowed_cidrs : can(cidrnetmask(c)) && c != "0.0.0.0/0"])
    error_message = "allowed_cidrs needs at least one valid IPv4 CIDR and must not be 0.0.0.0/0."
  }
}

variable "alb_group_name" {
  description = "AWS Load Balancer Controller IngressGroup. Ingresses with the same group share one ALB."
  type        = string
}

variable "repo_url" {
  description = "Git repository Argo CD reads from (HTTPS URL)."
  type        = string
}

variable "target_revision" {
  description = "Branch, tag or commit the root application tracks."
  type        = string
  default     = "main"
}

variable "apps_path" {
  description = "Folder in the repository with the child Application manifests (App of Apps)."
  type        = string
  default     = "gitops/apps"
}

variable "tags" {
  description = "Tags for the ALB. Pass the provider default tags: the ALB is created by the Load Balancer Controller, not Terraform. A plain value (not a data source) so the plan stays exact while the addons module has pending changes."
  type        = map(string)
  default     = {}
}
