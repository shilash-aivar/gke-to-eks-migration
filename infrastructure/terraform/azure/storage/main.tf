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

resource "azurerm_resource_group" "velero" {
  name     = var.velero_resource_group_name
  location = var.location

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "azurerm_storage_account" "velero" {
  name                            = var.velero_storage_account_name
  resource_group_name             = azurerm_resource_group.velero.name
  location                        = azurerm_resource_group.velero.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "azurerm_storage_container" "velero" {
  name                  = var.velero_container_name
  storage_account_name  = azurerm_storage_account.velero.name
  container_access_type = "private"
}
