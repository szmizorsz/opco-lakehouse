terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.50"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Account-level Databricks provider — points at the ACCOUNT console host, NOT a
# workspace. This is the provider that manages control-plane objects that have
# no Azure resource: the Unity Catalog metastore, its workspace assignments, and
# account-level groups. (infra/README.md: the azurerm vs databricks split.)
#
# Auth: Azure CLI / OIDC as an account admin — no secrets in code. The account
# ID comes from the account console (1:1 with the Entra tenant).
provider "databricks" {
  host       = "https://accounts.azuredatabricks.net"
  account_id = var.databricks_account_id
}
