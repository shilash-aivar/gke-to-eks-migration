variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Resource group name for networking resources"
  type        = string
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
}

variable "vnet_cidr" {
  description = "Address space for the VNet"
  type        = string
  default     = "10.0.0.0/8"
}

variable "aks_subnet_cidr" {
  description = "CIDR for AKS node subnet"
  type        = string
  default     = "10.240.0.0/16"
}

variable "pods_subnet_cidr" {
  description = "CIDR for AKS pod subnet (Azure CNI overlay)"
  type        = string
  default     = "10.241.0.0/16"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "poc"
}
