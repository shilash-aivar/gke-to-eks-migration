# ── Shared ────────────────────────────────────────────────────────────────
location    = "eastus"
environment = "dev"

# ── bootstrap (Terraform state storage) ──────────────────────────────────
tfstate_resource_group_name  = "aivar-tfstate-rg-dev"
tfstate_storage_account_name = "aivartfstatedev"
tfstate_container_name       = "tfstate"

# ── vnet ──────────────────────────────────────────────────────────────────
vnet_resource_group_name = "aivar-aks-network-rg-dev"
vnet_name                = "aivar-aks-vnet-dev"
vnet_cidr                = "10.0.0.0/8"
aks_subnet_cidr          = "10.240.0.0/16"
pods_subnet_cidr         = "10.241.0.0/16"

# ── aks ───────────────────────────────────────────────────────────────────
aks_resource_group_name = "aivar-aks-rg-dev"
cluster_name            = "aivar-aks-dev"
kubernetes_version      = "1.34"
aks_subnet_id           = "/subscriptions/a2ecae0d-874c-4ed1-873e-d95cb8f088b0/resourceGroups/aivar-aks-network-rg-dev/providers/Microsoft.Network/virtualNetworks/aivar-aks-vnet-dev/subnets/aivar-aks-vnet-dev-aks-nodes"
system_vm_size          = "Standard_DC2ads_v5"
system_node_count       = 1
user_vm_size            = "Standard_DC2ads_v5"
user_node_count         = 1
pod_cidr                = "10.244.0.0/16"
service_cidr            = "10.0.0.0/16"
dns_service_ip          = "10.0.0.10"

# ── storage (Velero blob storage) ─────────────────────────────────────────
velero_resource_group_name  = "aivar-velero-rg-dev"
velero_storage_account_name = "aivarvelerodev"
velero_container_name       = "velero-backups"

# ── helm-velero (Velero on AKS → AWS S3) ─────────────────────────────────
velero_bucket_name = "aivar-velero-backups-dev"
aws_region         = "us-east-1"
# aws_access_key_id and aws_secret_access_key must be set via env vars:
#   export TF_VAR_aws_access_key_id="..."
#   export TF_VAR_aws_secret_access_key="..."

# ── bootstrap-iam (Velero workload identity) ──────────────────────────────
identity_resource_group_name = "aivar-velero-rg-dev"
aks_cluster_name             = "aivar-aks-dev"
velero_identity_name         = "velero-workload-identity-dev"
velero_namespace             = "velero"
