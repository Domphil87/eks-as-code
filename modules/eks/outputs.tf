output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = aws_eks_cluster.this.arn
}

output "cluster_version" {
  description = "Kubernetes version of the control plane."
  value       = aws_eks_cluster.this.version
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint URL. Used by the kubernetes/helm providers in the platform layer."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 CA certificate of the cluster API. Used by the kubernetes/helm providers."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security group EKS attaches to the control plane and managed nodes."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "oidc_issuer_url" {
  description = "Cluster OIDC issuer URL (only needed if IRSA is used instead of Pod Identity)."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "node_role_arn" {
  description = "IAM role ARN of the worker nodes."
  value       = aws_iam_role.node.arn
}

output "node_group_name" {
  description = "Name of the managed node group."
  value       = aws_eks_node_group.default.node_group_name
}

output "node_group_asg_names" {
  description = "Auto Scaling group(s) behind the node group. Cluster Autoscaler scales these."
  value       = [for r in aws_eks_node_group.default.resources[0].autoscaling_groups : r.name]
}

output "efs_file_system_id" {
  description = "EFS file system ID for the EFS StorageClass (null if EFS is disabled)."
  value       = var.enable_efs ? aws_efs_file_system.this[0].id : null
}
