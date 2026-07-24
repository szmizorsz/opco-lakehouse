# The regional foundation — applied once, rarely changed (ADR-0001 topology):
#   * one Unity Catalog metastore for the region
#   * one workspace per environment (dev/uat/prd), all attached to that metastore
#   * account-level groups (the group platform team)
#
# Per-OpCo catalogs, external locations, SPNs and grants live in platform/, not
# here — this stack knows nothing about individual OpCos.

resource "azurerm_resource_group" "platform" {
  name     = var.resource_group_name
  location = var.region
}

module "metastore" {
  source = "../modules/metastore"
  name   = "lkh-metastore-${var.region}"
  region = var.region
}

# One workspace per environment — the orthogonal axis from ADR-0001. Workspaces
# are group-level (shared across OpCos); the OpCo boundary is the catalog.
module "workspace" {
  source   = "../modules/workspace"
  for_each = toset(var.environments)

  name                = "adb-lkh-${each.key}"
  env                 = each.key
  resource_group_name = azurerm_resource_group.platform.name
  location            = var.region
}

# Attach every environment workspace to the single regional metastore.
resource "databricks_metastore_assignment" "this" {
  for_each     = module.workspace
  workspace_id = each.value.workspace_id
  metastore_id = module.metastore.id
}

# Account-level group — the platform team. Per-OpCo RBAC groups
# (RBAC-LKH-{OPCO}-{role}) are created in the platform/ stack; this is the
# group-wide admin group that owns the metastore and templates.
resource "databricks_group" "platform_admins" {
  display_name = "RBAC-LKH-PLATFORM-Admin"
}
