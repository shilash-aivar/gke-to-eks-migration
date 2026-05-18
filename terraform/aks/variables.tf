variable "resource_group_name" {
  type        = string
  description = "Azure resource group for the AKS POC"
  default     = "rg-aks-velero-poc"
}

variable "location" {
  type        = string
  description = "Azure region"
  default     = "eastus"
}

variable "cluster_name" {
  type        = string
  description = "AKS cluster name"
  default     = "aks-velero-poc"
}

variable "dns_prefix" {
  type        = string
  description = "DNS prefix for the AKS API server"
  default     = "aksveleropoc"
}

variable "kubernetes_version" {
  type        = string
  description = "AKS Kubernetes version (leave null to use platform default)"
  default     = null
}

variable "node_count" {
  type        = number
  description = "Number of nodes in the default node pool"
  default     = 2
}

variable "vm_size" {
  type        = string
  description = "VM size for worker nodes (must be allowed in your subscription/region; see: az vm list-skus -l eastus)"
  default     = "Standard_DC2s_v3"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to Azure resources"
  default = {
    project = "aks-to-eks-velero-poc"
  }
}
