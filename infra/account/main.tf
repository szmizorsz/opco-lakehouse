# The regional foundation — applied once, rarely changed (ADR-0001 topology):
#   * one Unity Catalog metastore for the region — CREATED in a fresh region/sandbox,
#     or REUSED in a shared account where the region's metastore already exists
#   * one workspace per environment (dev/uat/prd), all attached to that metastore
#   * account-level groups (the group platform team)
#
# Per-OpCo catalogs, external locations, SPNs and grants live in platform/, not
# here — this stack knows nothing about individual OpCos.

# Datapao Azure Policy ("Tagging") requires these on every RG; propagated to
# the workspaces too so their tags are consistent.
locals {
  common_tags = {
    CostCenter         = var.cost_center
    ResourceGroupOwner = var.resource_group_owner
    platform           = "opco-lakehouse"
  }
}

resource "azurerm_resource_group" "platform" {
  name     = var.resource_group_name
  location = var.region
  tags     = local.common_tags
}

# Create-vs-reuse (ADR-0001): only one metastore may exist per region per account.
# When existing_metastore_id is set we reuse it; otherwise we create one.
module "metastore" {
  source = "../modules/metastore"
  count  = var.existing_metastore_id == "" ? 1 : 0
  name   = "opco-metastore-${var.region}"
  region = var.region
}

locals {
  metastore_id = var.existing_metastore_id != "" ? var.existing_metastore_id : module.metastore[0].id
}

# One workspace per environment — the orthogonal axis from ADR-0001. Workspaces
# are group-level (shared across OpCos); the OpCo boundary is the catalog.
module "workspace" {
  source   = "../modules/workspace"
  for_each = toset(var.environments)

  name                = "adb-opco-${each.key}"
  env                 = each.key
  resource_group_name = azurerm_resource_group.platform.name
  location            = var.region
  tags                = merge(local.common_tags, { env = each.key })
}

# Attach every environment workspace to the regional metastore (created or reused).
resource "databricks_metastore_assignment" "this" {
  for_each     = module.workspace
  workspace_id = each.value.workspace_id
  metastore_id = local.metastore_id
}

# Account-level group — the platform team. Per-OpCo RBAC groups
# (RBAC-OPCO-{OPCO}-{role}) are created in the platform/ stack; this is the
# group-wide admin group that owns the metastore and templates.
resource "databricks_group" "platform_admins" {
  display_name = "RBAC-OPCO-PLATFORM-Admin"
}
