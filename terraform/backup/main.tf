# This stack only holds the backups, so it can outlive the cluster.

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  tags = {
    project    = "gitlab-runner-on-azure"
    managed_by = "terraform"
  }
}

resource "azurerm_storage_account" "velero" {
  name                     = var.backup_storage_account
  resource_group_name      = data.azurerm_resource_group.this.name
  location                 = data.azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  # No access keys: Velero must log in with its Entra identity.
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  allow_nested_items_to_be_public = false

  tags = local.tags
}

resource "azurerm_storage_container" "velero" {
  name                  = "velero"
  storage_account_id    = azurerm_storage_account.velero.id
  container_access_type = "private"
}
