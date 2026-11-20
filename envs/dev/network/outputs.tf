# These outputs are the "contract" with the cluster layer, which reads them
# through terraform_remote_state. Renaming one breaks that layer.

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.network.vpc_id
}

output "vpc_cidr" {
  description = "IPv4 CIDR block of the VPC."
  value       = module.network.vpc_cidr
}

output "azs" {
  description = "Availability Zones used, in order."
  value       = module.network.azs
}

output "public_subnet_ids" {
  description = "Public subnet IDs, in AZ order."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs, in AZ order."
  value       = module.network.private_subnet_ids
}

output "private_route_table_ids" {
  description = "Private route table IDs, in AZ order."
  value       = module.network.private_route_table_ids
}

output "nat_public_ips" {
  description = "Public IPs of the NAT gateway(s)."
  value       = module.network.nat_public_ips
}

output "ci_runner_project_name" {
  description = "CodeBuild runner project; workflows use runs-on: codebuild-<name>-<run_id>-<run_attempt>. Null when disabled."
  value       = one(module.ci_runner[*].project_name)
}

output "ci_runner_security_group_id" {
  description = "Security group of the runner builds, allowed to the EKS API by the cluster layer. Null when disabled."
  value       = one(module.ci_runner[*].security_group_id)
}
