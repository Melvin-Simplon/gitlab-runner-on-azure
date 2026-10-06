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
