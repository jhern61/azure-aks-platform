output "resource_group_name" {
  description = "Name of the platform resource group."
  value       = azurerm_resource_group.this.name
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster."
  value       = module.aks.cluster_name
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL for Workload Identity federation."
  value       = module.aks.oidc_issuer_url
}

output "grafana_endpoint" {
  description = "Azure Managed Grafana endpoint."
  value       = module.monitoring.grafana_endpoint
}

output "kubeconfig_command" {
  description = "Command to fetch cluster credentials."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.this.name} --name ${module.aks.cluster_name}"
}
