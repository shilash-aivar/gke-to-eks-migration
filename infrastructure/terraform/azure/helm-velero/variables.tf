variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "aks_resource_group_name" {
  description = "Resource group of the AKS cluster"
  type        = string
}

variable "velero_bucket_name" {
  description = "AWS S3 bucket name for Velero backups"
  type        = string
}

variable "aws_region" {
  description = "AWS region where the S3 bucket lives"
  type        = string
  default     = "us-east-1"
}

variable "aws_access_key_id" {
  description = "AWS access key ID for Velero on AKS (set via TF_VAR_aws_access_key_id)"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS secret access key for Velero on AKS (set via TF_VAR_aws_secret_access_key)"
  type        = string
  sensitive   = true
}

variable "velero_namespace" {
  description = "Kubernetes namespace for Velero"
  type        = string
  default     = "velero"
}

variable "velero_chart_version" {
  description = "Velero Helm chart version"
  type        = string
  default     = "12.0.1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "poc"
}
