variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
  default     = "eks-velero-poc"
}

variable "region" {
  type        = string
  description = "AWS region (match Velero S3 bucket region)"
  default     = "us-east-1"
}

variable "vpc_id" {
  type        = string
  description = "Existing VPC ID (from partial terraform apply)"
  default     = "vpc-04bd992237aeae542"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for EKS (empty = auto-discover from VPC)"
  default     = []
}

variable "kubernetes_version" {
  type        = string
  description = "Target EKS minor version (e.g. 1.34 — patch/build is managed by AWS). One minor bump per upgrade; use scripts/upgrade-eks-version.sh to reach targets above current."
  default     = "1.34"
}

variable "node_instance_types" {
  type        = list(string)
  description = "EC2 instance types for the managed node group"
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  type        = number
  description = "Number of worker nodes (2 recommended for Velero restore + system pods)"
  default     = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}

variable "use_spot_instances" {
  type        = bool
  description = "Use Spot nodes (~70% cheaper). Set false for more reliable scheduling during restore."
  default     = false
}

variable "enable_ebs_csi_addon" {
  type        = bool
  description = "Install aws-ebs-csi-driver with IRSA (required for gp2 StorageClass / Velero PVCs)"
  default     = true
}

variable "node_assign_public_ip" {
  type        = bool
  description = "Assign public IPs to nodes (required for public subnets without NAT). Also run scripts/enable-subnet-public-ip.sh if subnets were created with map_public_ip_on_launch=false."
  default     = true
}

variable "cluster_enabled_log_types" {
  type        = list(string)
  description = "Control plane logs to CloudWatch (empty = disabled, saves $)"
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Must match existing resource tags exactly; org SCP denies eks:UntagResource / ec2:DeleteTags."
  default = {
    CreatedBy             = "shailesh.ms@aivar.tech"
    project               = "aks-to-eks-velero-poc"
    terraform-aws-modules = "eks"
  }
}
