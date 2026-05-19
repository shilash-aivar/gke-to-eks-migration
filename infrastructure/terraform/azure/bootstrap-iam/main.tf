terraform {
  required_version = ">= 1.10.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

data "azurerm_kubernetes_cluster" "this" {
  name                = var.aks_cluster_name
  resource_group_name = var.aks_resource_group_name
}

# Managed identity for Velero workload identity
resource "azurerm_user_assigned_identity" "velero" {
  name                = var.velero_identity_name
  resource_group_name = var.identity_resource_group_name
  location            = var.location

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Federated credential so Velero's k8s service account can assume the identity
resource "azurerm_federated_identity_credential" "velero" {
  name                = "${var.velero_identity_name}-federated"
  resource_group_name = var.identity_resource_group_name
  parent_id           = azurerm_user_assigned_identity.velero.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = data.azurerm_kubernetes_cluster.this.oidc_issuer_url
  subject             = "system:serviceaccount:${var.velero_namespace}:velero-server"
}

data "azurerm_storage_account" "velero" {
  name                = var.velero_storage_account_name
  resource_group_name = var.velero_resource_group_name
}

# Storage Blob Data Contributor on the Velero storage account
resource "azurerm_role_assignment" "velero_storage" {
  scope                = data.azurerm_storage_account.velero.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.velero.principal_id
}
