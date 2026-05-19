variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "velero_iam_role_name" {
  description = "Name of the Velero IRSA IAM role"
  type        = string
}

variable "velero_bucket_name" {
  description = "S3 bucket name for Velero backups"
  type        = string
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
