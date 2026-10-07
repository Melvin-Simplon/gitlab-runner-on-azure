data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  tags = {
    project    = "gitlab-runner-on-azure"
    managed_by = "terraform"
  }
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Free"

  # Needed later by Velero and the Azure metrics exporter to reach Azure without secrets.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Users log in with Entra ID, there is no shared admin kubeconfig.
  local_account_disabled = true
  azure_active_directory_role_based_access_control {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    azure_rbac_enabled = true
  }

  # No automatic upgrades, an extra node would use the shared vCPU quota.
  automatic_upgrade_channel = null
  node_os_upgrade_channel   = "None"

  default_node_pool {
    name       = "system"
    vm_size    = var.node_vm_size
    node_count = var.node_count
  }

  # Nodes only come from default_node_pool.
  node_provisioning_profile {
    mode = "Manual"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
  }

  tags = local.tags
}

# Created by the backup stack.
data "azurerm_storage_account" "velero" {
  name                = var.backup_storage_account
  resource_group_name = data.azurerm_resource_group.this.name
}

# Azure identity of Velero.
resource "azurerm_user_assigned_identity" "velero" {
  name                = "id-velero"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  tags                = local.tags
}

# Velero can only write in the backup storage account.
resource "azurerm_role_assignment" "velero_storage" {
  scope                = data.azurerm_storage_account.velero.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.velero.principal_id
}

# Only the Velero service account can use this identity.
resource "azurerm_federated_identity_credential" "velero" {
  name                      = "velero"
  user_assigned_identity_id = azurerm_user_assigned_identity.velero.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.this.oidc_issuer_url
  subject                   = "system:serviceaccount:velero:velero"
}

# Azure identity of the exporter.
resource "azurerm_user_assigned_identity" "azure_metrics" {
  name                = "id-azure-metrics"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  tags                = local.tags
}

# Read the storage account metrics.
resource "azurerm_role_assignment" "azure_metrics_project" {
  scope                = data.azurerm_resource_group.this.id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_user_assigned_identity.azure_metrics.principal_id
}

# Read the disk metrics in the AKS node group.
resource "azurerm_role_assignment" "azure_metrics_nodes" {
  scope                = azurerm_kubernetes_cluster.this.node_resource_group_id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_user_assigned_identity.azure_metrics.principal_id
}

# Only the exporter service account can use this identity.
resource "azurerm_federated_identity_credential" "azure_metrics" {
  name                      = "azure-metrics-exporter"
  user_assigned_identity_id = azurerm_user_assigned_identity.azure_metrics.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.this.oidc_issuer_url
  subject                   = "system:serviceaccount:azure-metrics:azure-metrics-exporter"
}
