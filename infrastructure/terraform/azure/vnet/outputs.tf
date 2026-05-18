output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.this.name
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.this.id
}

output "aks_subnet_id" {
  description = "ID of the AKS node subnet"
  value       = azurerm_subnet.aks_nodes.id
}

output "pods_subnet_id" {
  description = "ID of the AKS pod subnet"
  value       = azurerm_subnet.aks_pods.id
}
