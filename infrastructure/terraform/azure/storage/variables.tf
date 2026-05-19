variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "velero_resource_group_name" {
  description = "Resource group for Velero storage"
  type        = string
}

variable "velero_storage_account_name" {
  description = "Storage account name for Velero backups (3-24 chars, lowercase alphanumeric)"
  type        = string
}

variable "velero_container_name" {
  description = "Blob container name for Velero backups"
  type        = string
  default     = "velero-backups"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "poc"
}
