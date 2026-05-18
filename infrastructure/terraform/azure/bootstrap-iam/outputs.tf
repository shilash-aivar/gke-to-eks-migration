output "velero_identity_client_id" {
  description = "Client ID of the Velero managed identity"
  value       = azurerm_user_assigned_identity.velero.client_id
}

output "velero_identity_principal_id" {
  description = "Principal ID of the Velero managed identity"
  value       = azurerm_user_assigned_identity.velero.principal_id
}
