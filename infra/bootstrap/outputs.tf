output "argocd_namespace" {
  description = "Namespace where Argo CD runs."
  value       = helm_release.argocd.namespace
}

output "argocd_version" {
  description = "Argo CD application version installed by the chart."
  value       = helm_release.argocd.metadata.app_version
}

output "argocd_ui_command" {
  description = "Reach the Argo CD UI without exposing it: port-forward, then open https://localhost:8080."
  value       = "kubectl -n ${helm_release.argocd.namespace} port-forward svc/argocd-server 8080:443"
}

output "argocd_initial_password_command" {
  description = "Read the initial admin password. Rotate it, or move to SSO and disable the admin user."
  value       = "kubectl -n ${helm_release.argocd.namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}
