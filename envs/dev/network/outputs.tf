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
