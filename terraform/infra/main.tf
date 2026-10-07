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

# Storage account of the backup stack, which must be applied first.
data "azurerm_storage_account" "velero" {
  name                = var.backup_storage_account
  resource_group_name = data.azurerm_resource_group.this.name
}

# Azure identity that Velero borrows, without any secret.
resource "azurerm_user_assigned_identity" "velero" {
  name                = "id-velero"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  tags                = local.tags
}

# Velero may only read and write blobs in the backup storage account.
resource "azurerm_role_assignment" "velero_storage" {
  scope                = data.azurerm_storage_account.velero.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.velero.principal_id
}

# Only the velero service account of the velero namespace may use this identity.
resource "azurerm_federated_identity_credential" "velero" {
  name                      = "velero"
  user_assigned_identity_id = azurerm_user_assigned_identity.velero.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.this.oidc_issuer_url
  subject                   = "system:serviceaccount:velero:velero"
}
