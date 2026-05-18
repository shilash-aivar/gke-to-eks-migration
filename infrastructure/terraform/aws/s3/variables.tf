variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "velero_bucket_name" {
  description = "Name of the S3 bucket for Velero backups"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "poc"
}
