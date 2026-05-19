terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Use existing VPC from partial apply — do not manage VPC in Terraform (org SCP denies ec2:DeleteTags)
data "aws_subnets" "vpc" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

data "aws_subnet" "selected" {
  for_each = toset(data.aws_subnets.vpc.ids)
  id       = each.value
}

locals {
  # Prefer EKS-tagged public subnets; fall back to all subnets in the VPC
  tagged_subnet_ids = sort([
    for id, s in data.aws_subnet.selected : id
    if lookup(s.tags, "kubernetes.io/role/elb", "") == "1"
  ])
  subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : (
    length(local.tagged_subnet_ids) > 0 ? local.tagged_subnet_ids : sort(data.aws_subnets.vpc.ids)
  )
  capacity_type = var.use_spot_instances ? "SPOT" : "ON_DEMAND"
}

# AWS requires node groups at the current cluster version before a control plane bump.
# Terraform updates the cluster first; this runs sync before any module.eks changes.
resource "null_resource" "sync_nodegroups_before_upgrade" {
  triggers = {
    kubernetes_version = var.kubernetes_version
    cluster_name       = var.cluster_name
  }

  provisioner "local-exec" {
    command = "bash '${path.module}/scripts/sync-nodegroups-to-cluster.sh'"
  }
}

module "eks" {
  depends_on = [null_resource.sync_nodegroups_before_upgrade]
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = var.vpc_id
  subnet_ids = local.subnet_ids

  cluster_endpoint_public_access = true
  cluster_enabled_log_types      = var.cluster_enabled_log_types

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      name           = "default"
      subnet_ids     = local.subnet_ids
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
      capacity_type  = local.capacity_type

      # Public-subnet POC without NAT: nodes need a public IP (subnet must allow it too)
      network_interfaces = var.node_assign_public_ip ? [{
        associate_public_ip_address = true
        delete_on_termination       = true
        device_index                = 0
      }] : []
    }
  }

  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
  }

  tags = var.tags
}
