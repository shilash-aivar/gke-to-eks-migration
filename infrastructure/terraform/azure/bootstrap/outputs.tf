output "resource_group_name" {
  description = "Resource group name for Terraform state"
  value       = azurerm_resource_group.tfstate.name
}

output "storage_account_name" {
  description = "Storage account name for Terraform state"
  value       = azurerm_storage_account.tfstate.name
}

output "container_name" {
  description = "Blob container name for Terraform state"
  value       = azurerm_storage_container.tfstate.name
}
