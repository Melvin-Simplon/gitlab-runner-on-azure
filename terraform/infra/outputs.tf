output "cluster_name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "velero_client_id" {
  value = azurerm_user_assigned_identity.velero.client_id
}
