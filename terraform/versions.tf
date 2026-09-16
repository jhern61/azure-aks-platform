terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state. Values are supplied via `terraform init -backend-config=...`
  # or an environment-specific backend file so no secrets live in the repo.
  # Bootstrap the storage account with `make bootstrap`.
  backend "azurerm" {}
}
