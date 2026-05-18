variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "velero_namespace" {
  description = "Kubernetes namespace where Velero is installed"
  type        = string
  default     = "velero"
}

variable "velero_bucket_name" {
  description = "S3 bucket name used by Velero for backups"
  type        = string
}

variable "velero_iam_role_name" {
  description = "Name of the IAM role for Velero IRSA"
  type        = string
  default     = "velero-irsa-role"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "poc"
}
