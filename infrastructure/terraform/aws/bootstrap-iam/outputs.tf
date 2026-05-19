output "velero_iam_role_arn" {
  description = "ARN of the Velero IRSA IAM role"
  value       = aws_iam_role.velero.arn
}

output "velero_iam_role_name" {
  description = "Name of the Velero IRSA IAM role"
  value       = aws_iam_role.velero.name
}

output "ebs_csi_role_arn" {
  description = "ARN of the EBS CSI driver IRSA role"
  value       = aws_iam_role.ebs_csi.arn
}
