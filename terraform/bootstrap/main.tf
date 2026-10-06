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
