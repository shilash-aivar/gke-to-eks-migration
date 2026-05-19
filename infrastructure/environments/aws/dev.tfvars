# ── Shared ────────────────────────────────────────────────────────────────
aws_region  = "us-east-1"
environment = "dev"

# ── bootstrap (Terraform state bucket) ───────────────────────────────────
state_bucket_name = "shilash-tf-state-bucket"

# ── vpc ───────────────────────────────────────────────────────────────────
vpc_name             = "aivar-eks-vpc-dev"
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

# ── eks ───────────────────────────────────────────────────────────────────
cluster_name        = "aivar-eks-dev"
kubernetes_version  = "1.34"
vpc_id              = "vpc-01b74c3cde35c3436"
private_subnet_ids  = ["subnet-0c0319a2c309a04ed", "subnet-074e827267cbbf330"]
node_instance_types = ["t3.medium"]
node_desired_size   = 4
node_min_size       = 1
node_max_size       = 5

# ── s3 (Velero backup bucket) ─────────────────────────────────────────────
velero_bucket_name = "aivar-velero-backups-dev"

# ── bootstrap-iam (Velero IRSA role) ─────────────────────────────────────
aws_account_id       = "511568813295"
eks_cluster_name     = "aivar-eks-dev"
velero_namespace     = "velero"
velero_iam_role_name = "velero-irsa-role-dev"
