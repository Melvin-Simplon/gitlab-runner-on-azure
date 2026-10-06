terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.8"
    }
  }

  # GitLab-managed state, address and credentials set by scripts/tf.sh (TF_HTTP_* variables).
  backend "http" {}
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  # Students cannot register Azure providers, so Terraform must not try.
  resource_provider_registrations = "none"
}
