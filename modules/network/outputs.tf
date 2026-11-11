# Lists are returned in the same order as var.azs, so index 0 is always the
# first AZ. The cluster layer reads these through terraform_remote_state.

output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "IPv4 CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "azs" {
  description = "Availability Zones used, in order."
  value       = var.azs
}

output "public_subnet_ids" {
  description = "Public subnet IDs (load balancers, NAT), in AZ order."
  value       = [for az in var.azs : aws_subnet.public[az].id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs (EKS nodes and pods), in AZ order."
  value       = [for az in var.azs : aws_subnet.private[az].id]
}

output "private_route_table_ids" {
  description = "Private route table IDs, in AZ order."
  value       = [for az in var.azs : aws_route_table.private[az].id]
}

output "nat_public_ips" {
  description = "Public IPs of the NAT gateway(s). All outbound traffic from private subnets appears to come from these."
  value       = [for az in sort(tolist(local.nat_azs)) : aws_eip.nat[az].public_ip]
}
