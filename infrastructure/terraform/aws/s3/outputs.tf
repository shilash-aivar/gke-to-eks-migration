output "velero_bucket_name" {
  description = "Name of the Velero S3 bucket"
  value       = aws_s3_bucket.velero.bucket
}

output "velero_bucket_arn" {
  description = "ARN of the Velero S3 bucket"
  value       = aws_s3_bucket.velero.arn
}
