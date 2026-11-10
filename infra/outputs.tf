output "resource_group_name" {
  description = "Resource group holding the cluster, network and monitoring."
  value       = azurerm_resource_group.this.name
}

output "cluster_name" {
  description = "AKS cluster name. Feed this to the bootstrap root."
  value       = azurerm_kubernetes_cluster.this.name
}

output "cluster_id" {
  description = "AKS cluster resource ID, the scope for extra Azure RBAC assignments."
  value       = azurerm_kubernetes_cluster.this.id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL. Use it as the issuer when creating federated credentials for workload identity."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet identity, for example to grant AcrPull on a registry."
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace receiving Container Insights and control plane logs."
  value       = azurerm_log_analytics_workspace.this.id
}

output "get_credentials_command" {
  description = "Fetch a kubeconfig that authenticates through Entra ID via kubelogin."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.this.name} --name ${azurerm_kubernetes_cluster.this.name} && kubelogin convert-kubeconfig -l azurecli"
}
