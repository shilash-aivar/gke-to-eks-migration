output "storage_account_name" {
  description = "Name of the Velero storage account"
  value       = azurerm_storage_account.velero.name
}

output "container_name" {
  description = "Name of the Velero blob container"
  value       = azurerm_storage_container.velero.name
}

output "storage_account_id" {
  description = "ID of the Velero storage account"
  value       = azurerm_storage_account.velero.id
}
