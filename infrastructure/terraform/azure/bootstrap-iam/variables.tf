variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Resource group for the managed identity"
  type        = string
}

variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "aks_resource_group_name" {
  description = "Resource group of the AKS cluster"
  type        = string
}

variable "velero_identity_name" {
  description = "Name of the Velero managed identity"
  type        = string
  default     = "velero-workload-identity"
}

variable "velero_namespace" {
  description = "Kubernetes namespace where Velero is installed"
  type        = string
  default     = "velero"
}

variable "velero_storage_account_name" {
  description = "Storage account name used by Velero for backups"
  type        = string
}

variable "velero_storage_resource_group" {
  description = "Resource group of the Velero storage account"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "poc"
}
