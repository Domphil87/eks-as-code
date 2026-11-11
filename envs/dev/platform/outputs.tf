output "ebs_csi_role_arn" {
  description = "IAM role used by the EBS CSI controller."
  value       = module.addons.ebs_csi_role_arn
}

output "efs_csi_role_arn" {
  description = "IAM role used by the EFS CSI controller."
  value       = module.addons.efs_csi_role_arn
}

output "lbc_role_arn" {
  description = "IAM role used by the AWS Load Balancer Controller."
  value       = module.addons.lbc_role_arn
}

output "external_dns_role_arn" {
  description = "IAM role used by ExternalDNS."
  value       = module.addons.external_dns_role_arn
}

output "cert_manager_role_arn" {
  description = "IAM role used by cert-manager."
  value       = module.addons.cert_manager_role_arn
}

output "external_secrets_role_arn" {
  description = "IAM role used by External Secrets Operator."
  value       = module.addons.external_secrets_role_arn
}

output "cluster_secret_store_name" {
  description = "ClusterSecretStore for AWS Secrets Manager."
  value       = module.addons.cluster_secret_store_name
}

output "demo_secret_name" {
  description = "Demo secret in Secrets Manager."
  value       = module.addons.demo_secret_name
}

output "container_log_group" {
  description = "CloudWatch log group with container logs."
  value       = module.addons.container_log_group
}

output "grafana_admin_secret_name" {
  description = "Secrets Manager secret with the Grafana admin login."
  value       = module.addons.grafana_admin_secret_name
}

output "grafana_port_forward" {
  description = "Open Grafana on http://localhost:3000."
  value       = "kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
}

output "dns_subdomain" {
  description = "Subdomain for application host names."
  value       = module.addons.dns_subdomain
}

output "acm_certificate_arn" {
  description = "Wildcard ACM certificate used by ALBs."
  value       = module.addons.acm_certificate_arn
}

output "default_storage_class" {
  description = "Default StorageClass name."
  value       = module.addons.default_storage_class
}

output "efs_storage_class" {
  description = "EFS StorageClass name."
  value       = module.addons.efs_storage_class
}
