output "velero_release_status" {
  description = "Status of the Velero Helm release on AKS"
  value       = helm_release.velero.status
}
