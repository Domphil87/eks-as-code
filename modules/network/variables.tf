variable "name" {
  description = "Name prefix for every network resource, for example eks-platform-as-code-dev."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC, for example 10.10.0.0/16."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "azs" {
  description = "Availability Zone names to use. One public and one private subnet is created in each."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2 && length(var.azs) == length(distinct(var.azs))
    error_message = "Provide at least 2 distinct Availability Zones (EKS requires subnets in 2+ AZs)."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, in the same order as azs."
  type        = list(string)

  validation {
    condition     = alltrue([for c in var.public_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "Every public subnet CIDR must be a valid IPv4 CIDR block."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (worker nodes and pods), in the same order as azs."
  type        = list(string)

  validation {
    condition     = alltrue([for c in var.private_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "Every private subnet CIDR must be a valid IPv4 CIDR block."
  }
}

variable "single_nat_gateway" {
  description = "true = one shared NAT gateway (cheaper, single-AZ dependency). false = one NAT gateway per AZ (resilient)."
  type        = bool
  default     = true
}

variable "enable_s3_gateway_endpoint" {
  description = "Create a free S3 gateway endpoint so S3/ECR-layer traffic from private subnets bypasses the NAT gateway."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Extra tags for every resource. Standard tags normally come from the provider's default_tags."
  type        = map(string)
  default     = {}
}
