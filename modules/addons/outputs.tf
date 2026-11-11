output "ebs_csi_role_arn" {
  description = "IAM role used by the EBS CSI controller (Pod Identity)."
  value       = aws_iam_role.ebs_csi.arn
}

output "efs_csi_role_arn" {
  description = "IAM role used by the EFS CSI controller (null if EFS is disabled)."
  value       = local.enable_efs ? aws_iam_role.efs_csi[0].arn : null
}

output "lbc_role_arn" {
  description = "IAM role used by the AWS Load Balancer Controller."
  value       = aws_iam_role.lbc.arn
}

output "external_dns_role_arn" {
  description = "IAM role used by ExternalDNS."
  value       = aws_iam_role.external_dns.arn
}

output "cert_manager_role_arn" {
  description = "IAM role used by cert-manager for DNS-01 challenges."
  value       = aws_iam_role.cert_manager.arn
}

output "external_secrets_role_arn" {
  description = "IAM role used by External Secrets Operator."
  value       = aws_iam_role.external_secrets.arn
}

output "cluster_secret_store_name" {
  description = "ClusterSecretStore that ExternalSecrets reference to read from Secrets Manager."
  value       = local.cluster_secret_store
}

output "demo_secret_name" {
  description = "Name of the demo secret in Secrets Manager (null if not created)."
  value       = var.create_demo_secret ? aws_secretsmanager_secret.demo[0].name : null
}

output "fluent_bit_role_arn" {
  description = "IAM role used by Fluent Bit."
  value       = aws_iam_role.fluent_bit.arn
}

output "container_log_group" {
  description = "CloudWatch log group receiving container logs."
  value       = aws_cloudwatch_log_group.containers.name
}

output "grafana_admin_secret_name" {
  description = "Secrets Manager secret holding the Grafana admin login."
  value       = aws_secretsmanager_secret.grafana_admin.name
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role used by Cluster Autoscaler."
  value       = aws_iam_role.cluster_autoscaler.arn
}

output "dns_subdomain" {
  description = "Subdomain for this environment's application host names."
  value       = var.dns_subdomain
}

output "acm_certificate_arn" {
  description = "Validated wildcard ACM certificate for *.<dns_subdomain> (used by ALBs)."
  value       = aws_acm_certificate_validation.wildcard.certificate_arn
}

output "default_storage_class" {
  description = "Name of the default StorageClass."
  value       = kubernetes_storage_class_v1.gp3.metadata[0].name
}

output "efs_storage_class" {
  description = "Name of the EFS StorageClass (null if EFS is disabled)."
  value       = local.enable_efs ? kubernetes_storage_class_v1.efs[0].metadata[0].name : null
}
