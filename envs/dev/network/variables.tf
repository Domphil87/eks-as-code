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

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
}

variable "azs" {
  description = "Availability Zones to use (must all support EKS)."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, one per AZ, same order as azs."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs, one per AZ, same order as azs."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "true = one shared NAT gateway; false = one per AZ."
  type        = bool
}
