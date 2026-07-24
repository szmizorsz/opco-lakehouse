# One Azure Databricks workspace = one "Azure Databricks Service" resource
# (Microsoft.Databricks/workspaces). Premium SKU is required for Unity Catalog
# and the granular access control the platform relies on.
#
# Workspaces are group-level and per-environment (ADR-0001): the OpCo boundary
# is the catalog, not the workspace, so nothing here is OpCo-specific.
resource "azurerm_databricks_workspace" "this" {
  name                        = var.name
  resource_group_name         = var.resource_group_name
  location                    = var.location
  sku                         = "premium"
  managed_resource_group_name = "${var.resource_group_name}-${var.env}-managed"

  tags = {
    platform = "opco-lakehouse"
    env      = var.env
  }
}
