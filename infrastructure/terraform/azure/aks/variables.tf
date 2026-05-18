variable "resource_group_name" {
  description = "Resource group for the AKS cluster"
  type        = string
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "aks_subnet_id" {
  description = "Subnet ID for AKS nodes"
  type        = string
}

variable "system_vm_size" {
  description = "VM size for the system node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "system_node_count" {
  description = "Node count for the system node pool"
  type        = number
  default     = 1
}

variable "user_vm_size" {
  description = "VM size for the user node pool"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "user_node_count" {
  description = "Node count for the user node pool"
  type        = number
  default     = 2
}

variable "pod_cidr" {
  description = "CIDR for pods (Azure CNI)"
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "CIDR for Kubernetes services"
  type        = string
  default     = "10.0.0.0/16"
}

variable "dns_service_ip" {
  description = "DNS service IP (must be within service_cidr)"
  type        = string
  default     = "10.0.0.10"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "poc"
}
