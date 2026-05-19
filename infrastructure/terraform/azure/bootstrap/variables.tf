variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "tfstate_resource_group_name" {
  description = "Resource group for Terraform state storage"
  type        = string
}

variable "tfstate_storage_account_name" {
  description = "Storage account name for Terraform state (3-24 chars, lowercase alphanumeric)"
  type        = string
}

variable "tfstate_container_name" {
  description = "Blob container name for Terraform state"
  type        = string
  default     = "tfstate"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "poc"
}
