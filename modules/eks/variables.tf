# ---------------------------------------------------------------
# Cluster
# ---------------------------------------------------------------
variable "cluster_name" {
  description = "Name of the EKS cluster. Also used as a prefix for related resources."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes minor version, for example 1.36. Upgrades are one minor version at a time."
  type        = string

  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.kubernetes_version))
    error_message = "kubernetes_version must look like 1.36."
  }
}

variable "vpc_id" {
  description = "VPC that the cluster and EFS live in."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets (one per AZ) for the control-plane ENIs, nodes and EFS mount targets."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "EKS needs subnets in at least 2 Availability Zones."
  }
}

# ---------------------------------------------------------------
# API access
# ---------------------------------------------------------------
variable "endpoint_public_access" {
  description = "Expose the Kubernetes API on a public endpoint (restricted by endpoint_public_access_cidrs)."
  type        = bool
  default     = true
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint, for example your home IP as x.x.x.x/32."
  type        = list(string)

  validation {
    condition     = !contains(var.endpoint_public_access_cidrs, "0.0.0.0/0") && length(var.endpoint_public_access_cidrs) > 0
    error_message = "Do not open the API to 0.0.0.0/0; list specific CIDRs."
  }
}

variable "cluster_admin_principal_arns" {
  description = "IAM user/role ARNs that get cluster-admin through EKS access entries."
  type        = list(string)
}

# ---------------------------------------------------------------
# Logging
# ---------------------------------------------------------------
variable "enabled_log_types" {
  description = "Control-plane log types sent to CloudWatch. Options: api, audit, authenticator, controllerManager, scheduler."
  type        = list(string)
  default     = ["audit", "authenticator"]
}

variable "log_retention_days" {
  description = "Days to keep control-plane logs in CloudWatch."
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.log_retention_days)
    error_message = "log_retention_days must be a value CloudWatch accepts, for example 7, 14 or 30."
  }
}

# ---------------------------------------------------------------
# Add-ons
# ---------------------------------------------------------------
variable "addon_versions" {
  description = "Pinned versions of the core EKS add-ons. Find them with: aws eks describe-addon-versions --kubernetes-version <v> --addon-name <name>."
  type        = map(string)

  validation {
    condition     = alltrue([for a in ["vpc-cni", "kube-proxy", "coredns", "eks-pod-identity-agent"] : contains(keys(var.addon_versions), a)])
    error_message = "addon_versions must contain vpc-cni, kube-proxy, coredns and eks-pod-identity-agent."
  }
}

# ---------------------------------------------------------------
# Nodes
# ---------------------------------------------------------------
variable "node_instance_types" {
  description = "Instance types for the managed node group. Keep them the same CPU/memory size so Cluster Autoscaler can reason about them."
  type        = list(string)
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT."
  type        = string

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "node_min_size" {
  description = "Minimum number of nodes."
  type        = number
}

variable "node_desired_size" {
  description = "Initial number of nodes. After creation, Cluster Autoscaler owns this value."
  type        = number
}

variable "node_max_size" {
  description = "Maximum number of nodes Cluster Autoscaler may scale to."
  type        = number
}

variable "node_disk_size_gib" {
  description = "Root volume size per node (container images are stored here)."
  type        = number
  default     = 30
}

# ---------------------------------------------------------------
# EFS
# ---------------------------------------------------------------
variable "enable_efs" {
  description = "Create an EFS file system with mount targets in every private subnet."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Extra tags for every resource. Standard tags normally come from provider default_tags."
  type        = map(string)
  default     = {}
}
