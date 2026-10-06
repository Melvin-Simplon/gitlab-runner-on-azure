terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.8"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
  }

  # GitLab-managed state, address and credentials set by scripts/tf.sh (TF_HTTP_* variables).
  backend "http" {}
}

provider "azurerm" {
  features {}
  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
}

# Server application ID of the AKS Entra integration, the same for every AKS cluster.
locals {
  aks_server_id = "6dae42f8-4368-4678-94ff-3960e28e3630"
}

provider "helm" {
  kubernetes = {
    host                   = data.azurerm_kubernetes_cluster.this.kube_config[0].host
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)
    # Reuses your az CLI session.
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      args        = ["get-token", "--login", "azurecli", "--server-id", local.aks_server_id]
    }
  }
}
