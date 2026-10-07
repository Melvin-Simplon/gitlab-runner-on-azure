data "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  resource_group_name = var.resource_group_name
}

locals {
  k8s_dir = "${path.module}/../../k8s/argocd"
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true
  values           = [file("${local.k8s_dir}/values.yaml")]
}

# Root application, installed with a chart so the ArgoCD CRDs are not needed at plan time.
resource "helm_release" "root_app" {
  name       = "argocd-root"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version
  namespace  = "argocd"
  values     = [file("${local.k8s_dir}/root-app.yaml")]

  depends_on = [helm_release.argocd]
}

# Identity of the infra stack, read here because its id changes with each new cluster.
data "azurerm_user_assigned_identity" "velero" {
  name                = "id-velero"
  resource_group_name = var.resource_group_name
}

resource "kubernetes_namespace_v1" "velero" {
  metadata {
    name = "velero"
  }
}

# Velero runs with this service account, linked here to its Azure identity.
resource "kubernetes_service_account_v1" "velero" {
  metadata {
    name      = "velero"
    namespace = kubernetes_namespace_v1.velero.metadata[0].name
    annotations = {
      "azure.workload.identity/client-id" = data.azurerm_user_assigned_identity.velero.client_id
    }
  }
}

# Azure ids for the Velero plugin, with no password inside.
resource "kubernetes_secret_v1" "velero_azure" {
  metadata {
    name      = "velero-azure"
    namespace = kubernetes_namespace_v1.velero.metadata[0].name
  }
  data = {
    cloud = <<-EOT
      AZURE_SUBSCRIPTION_ID=${var.subscription_id}
      AZURE_RESOURCE_GROUP=${var.resource_group_name}
      AZURE_CLOUD_NAME=AzurePublicCloud
    EOT
  }
}
