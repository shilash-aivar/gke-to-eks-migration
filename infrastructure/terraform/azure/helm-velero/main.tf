terraform {
  required_version = ">= 1.10.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

data "azurerm_kubernetes_cluster" "this" {
  name                = var.aks_cluster_name
  resource_group_name = var.aks_resource_group_name
}

provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.this.kube_config[0].host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)
  }
}

resource "helm_release" "velero" {
  name             = "velero"
  repository       = "https://vmware-tanzu.github.io/helm-charts"
  chart            = "velero"
  version          = var.velero_chart_version
  namespace        = var.velero_namespace
  create_namespace = true

  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      velero_bucket_name    = var.velero_bucket_name
      aws_region            = var.aws_region
      aws_access_key_id     = var.aws_access_key_id
      aws_secret_access_key = var.aws_secret_access_key
    })
  ]
}
