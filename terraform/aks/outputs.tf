output "resource_group_name" {
  value       = azurerm_resource_group.main.name
}

output "cluster_name" {
  value       = azurerm_kubernetes_cluster.aks.name
}

output "cluster_fqdn" {
  value       = azurerm_kubernetes_cluster.aks.fqdn
}

output "kube_config_raw" {
  description = "Raw kubeconfig for kubectl / helm"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "get_credentials_command" {
  description = "Merge AKS credentials into ~/.kube/config"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.aks.name} --overwrite-existing"
}

output "default_storage_classes" {
  description = "Typical AKS default storage classes to map on EKS restore"
  value = [
    "managed-csi",
    "managed-csi-premium",
    "azurefile-csi",
  ]
}
