output "vpc_id" {
  value = var.vpc_id
}

output "subnet_ids" {
  value = local.subnet_ids
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "region" {
  value = var.region
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  description = "Configure kubectl for the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "velero_s3_bucket" {
  description = "Use the same bucket as AKS source backups"
  value       = "migration-bucket-aks-eks-velero-poc"
}
