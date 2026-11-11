output "argocd_namespace" {
  description = "Namespace Argo CD runs in."
  value       = kubernetes_namespace_v1.argocd.metadata[0].name
}

output "argocd_url" {
  description = "Argo CD UI (reachable only from allowed_cidrs)."
  value       = "https://${var.hostname}"
}

output "root_app_name" {
  description = "Name of the root App of Apps Application."
  value       = local.root_app_name
}
