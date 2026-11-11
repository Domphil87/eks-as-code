# Contract with the platform layer (read via terraform_remote_state).

output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = module.eks.cluster_arn
}

output "cluster_version" {
  description = "Kubernetes version."
  value       = module.eks.cluster_version
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 CA certificate of the cluster API."
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_security_group_id" {
  description = "EKS cluster security group."
  value       = module.eks.cluster_security_group_id
}

output "oidc_issuer_url" {
  description = "Cluster OIDC issuer URL."
  value       = module.eks.oidc_issuer_url
}

output "node_role_arn" {
  description = "Worker node IAM role ARN."
  value       = module.eks.node_role_arn
}

output "node_group_name" {
  description = "Managed node group name."
  value       = module.eks.node_group_name
}

output "node_group_asg_names" {
  description = "Auto Scaling groups behind the node group."
  value       = module.eks.node_group_asg_names
}

output "efs_file_system_id" {
  description = "EFS file system ID."
  value       = module.eks.efs_file_system_id
}

output "configure_kubectl" {
  description = "Command to point kubectl at this cluster."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
