# ── Shared ────────────────────────────────────────────────────────────────
aws_region  = "us-east-1"
environment = "prod"

# ── bootstrap (Terraform state bucket) ───────────────────────────────────
state_bucket_name = "aivar-terraform-state-prod"

# ── vpc ───────────────────────────────────────────────────────────────────
vpc_name             = "aivar-eks-vpc-prod"
vpc_cidr             = "10.1.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
private_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24", "10.1.13.0/24"]

# ── eks ───────────────────────────────────────────────────────────────────
cluster_name        = "aivar-eks-prod"
kubernetes_version  = "1.31"
vpc_id              = ""   # populate after vpc apply
private_subnet_ids  = []   # populate after vpc apply
node_instance_types = ["t3.large"]
node_desired_size   = 3
node_min_size       = 2
node_max_size       = 6

# ── s3 (Velero backup bucket) ─────────────────────────────────────────────
velero_bucket_name = "aivar-velero-backups-prod"

# ── bootstrap-iam (Velero IRSA role) ─────────────────────────────────────
aws_account_id       = "511568813295"
eks_cluster_name     = "aivar-eks-prod"
velero_namespace     = "velero"
velero_iam_role_name = "velero-irsa-role-prod"
