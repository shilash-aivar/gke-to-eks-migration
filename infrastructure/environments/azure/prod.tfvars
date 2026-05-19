# ── Shared ────────────────────────────────────────────────────────────────
location    = "eastus"
environment = "prod"

# ── bootstrap (Terraform state storage) ──────────────────────────────────
tfstate_resource_group_name  = "aivar-tfstate-rg-prod"
tfstate_storage_account_name = "aivartfstateprod"
tfstate_container_name       = "tfstate"

# ── vnet ──────────────────────────────────────────────────────────────────
vnet_resource_group_name = "aivar-aks-network-rg-prod"
vnet_name                = "aivar-aks-vnet-prod"
vnet_cidr                = "10.1.0.0/8"
aks_subnet_cidr          = "10.1.240.0/16"
pods_subnet_cidr         = "10.1.241.0/16"

# ── aks ───────────────────────────────────────────────────────────────────
aks_resource_group_name = "aivar-aks-rg-prod"
cluster_name            = "aivar-aks-prod"
kubernetes_version      = "1.31"
aks_subnet_id           = ""   # populate after vnet apply
system_vm_size          = "Standard_D4s_v3"
system_node_count       = 2
user_vm_size            = "Standard_D8s_v3"
user_node_count         = 3
pod_cidr                = "10.244.0.0/16"
service_cidr            = "10.0.0.0/16"
dns_service_ip          = "10.0.0.10"

# ── storage (Velero blob storage) ─────────────────────────────────────────
velero_resource_group_name  = "aivar-velero-rg-prod"
velero_storage_account_name = "aivarvelerprod"
velero_container_name       = "velero-backups"

# ── bootstrap-iam (Velero workload identity) ──────────────────────────────
identity_resource_group_name = "aivar-velero-rg-prod"
aks_cluster_name             = "aivar-aks-prod"
velero_identity_name         = "velero-workload-identity-prod"
velero_namespace             = "velero"
