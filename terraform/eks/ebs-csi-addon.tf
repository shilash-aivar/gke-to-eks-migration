# EBS CSI needs an IRSA role; installing via cluster_addons without service_account_role_arn
# often leaves the addon stuck in CREATING. Managed separately after the cluster and nodes exist.

data "aws_eks_addon_version" "ebs_csi" {
  count = var.enable_ebs_csi_addon ? 1 : 0

  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = module.eks.cluster_version
  most_recent        = true
}

module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"
  count   = var.enable_ebs_csi_addon ? 1 : 0

  role_name_prefix = "${var.cluster_name}-ebs-csi-"

  role_policy_arns = {
    ebs_csi = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.tags

  depends_on = [module.eks]
}

resource "aws_eks_addon" "ebs_csi" {
  count = var.enable_ebs_csi_addon ? 1 : 0

  cluster_name                = module.eks.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = data.aws_eks_addon_version.ebs_csi[0].version
  service_account_role_arn    = module.ebs_csi_irsa[0].iam_role_arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    module.eks,
    module.ebs_csi_irsa,
  ]

  tags = var.tags
}
