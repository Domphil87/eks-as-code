variable "cluster_name" {
  description = "Name of the EKS cluster the add-ons are installed into."
  type        = string
}

variable "cluster_arn" {
  description = "ARN of the EKS cluster. Pod Identity roles trust only this cluster."
  type        = string
}

variable "addon_versions" {
  description = "Pinned EKS add-on versions. Must contain aws-ebs-csi-driver, aws-efs-csi-driver, metrics-server and fluent-bit."
  type        = map(string)

  validation {
    condition = alltrue([
      for name in ["aws-ebs-csi-driver", "aws-efs-csi-driver", "metrics-server", "fluent-bit"] :
      contains(keys(var.addon_versions), name)
    ])
    error_message = "addon_versions must contain aws-ebs-csi-driver, aws-efs-csi-driver, metrics-server and fluent-bit."
  }
}

variable "chart_versions" {
  description = "Pinned Helm chart versions. Must contain aws-load-balancer-controller, external-dns, cert-manager, external-secrets, kube-prometheus-stack and cluster-autoscaler."
  type        = map(string)

  validation {
    condition = alltrue([
      for name in ["aws-load-balancer-controller", "external-dns", "cert-manager", "external-secrets", "kube-prometheus-stack", "cluster-autoscaler"] :
      contains(keys(var.chart_versions), name)
    ])
    error_message = "chart_versions must contain aws-load-balancer-controller, external-dns, cert-manager, external-secrets, kube-prometheus-stack and cluster-autoscaler."
  }
}

variable "cluster_autoscaler_version" {
  description = "Cluster Autoscaler image tag. Its minor version must match the cluster's Kubernetes version, for example v1.36.2 for 1.36."
  type        = string

  validation {
    condition     = can(regex("^v1\\.[0-9]+\\.[0-9]+$", var.cluster_autoscaler_version))
    error_message = "cluster_autoscaler_version must look like v1.36.2."
  }
}

variable "cluster_autoscaler_scale_down_unneeded_time" {
  description = "How long a node must be unneeded before Cluster Autoscaler removes it, for example 5m or 10m."
  type        = string
  default     = "10m"

  validation {
    condition     = can(regex("^[0-9]+(s|m|h)$", var.cluster_autoscaler_scale_down_unneeded_time))
    error_message = "cluster_autoscaler_scale_down_unneeded_time must look like 5m."
  }
}

variable "prometheus_retention" {
  description = "How long Prometheus keeps metrics, for example 2d or 15d."
  type        = string
  default     = "2d"

  validation {
    condition     = can(regex("^[0-9]+(h|d|w)$", var.prometheus_retention))
    error_message = "prometheus_retention must look like 12h, 2d or 2w."
  }
}

variable "prometheus_storage_gib" {
  description = "Size of the Prometheus gp3 volume in GiB."
  type        = number
  default     = 10

  validation {
    condition     = var.prometheus_storage_gib >= 5
    error_message = "prometheus_storage_gib must be at least 5."
  }
}

variable "container_log_retention_days" {
  description = "CloudWatch retention for container logs shipped by Fluent Bit."
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.container_log_retention_days)
    error_message = "container_log_retention_days must be a value CloudWatch Logs supports, for example 7, 14 or 30."
  }
}

variable "secrets_prefix" {
  description = "Secrets Manager name prefix this environment may read, without trailing slash, for example myproject/dev."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.@-]+(/[A-Za-z0-9_.@-]+)*$", var.secrets_prefix))
    error_message = "secrets_prefix must be a Secrets Manager path such as myproject/dev (no leading or trailing slash)."
  }
}

variable "create_demo_secret" {
  description = "Create <secrets_prefix>/demo with a generated value, for testing External Secrets Operator."
  type        = bool
  default     = false
}

variable "secret_recovery_window_days" {
  description = "Days Secrets Manager keeps a deleted secret recoverable. 0 deletes immediately (dev); 7-30 otherwise."
  type        = number
  default     = 30

  validation {
    condition     = var.secret_recovery_window_days == 0 || (var.secret_recovery_window_days >= 7 && var.secret_recovery_window_days <= 30)
    error_message = "secret_recovery_window_days must be 0 or between 7 and 30."
  }
}

variable "parent_domain" {
  description = "Existing public Route 53 hosted zone, for example example.com. Looked up, never modified at the apex."
  type        = string
}

variable "dns_subdomain" {
  description = "Subdomain this environment owns inside parent_domain, for example dev.example.com. ExternalDNS and cert-manager may only change records under it."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+(\\.[a-z0-9-]+)+$", var.dns_subdomain))
    error_message = "dns_subdomain must be a lowercase DNS name such as dev.example.com."
  }
}

variable "efs_file_system_id" {
  description = "EFS file system for the efs StorageClass. null skips the EFS CSI driver and StorageClass."
  type        = string
  default     = null
}

variable "tags" {
  description = "Extra tags for AWS resources (provider default_tags are applied automatically)."
  type        = map(string)
  default     = {}
}
