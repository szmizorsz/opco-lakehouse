# Unity Catalog metastore — one per region (ADR-0001).
#
# Created WITHOUT a metastore-level root storage on purpose: modern UC keeps
# managed storage at the CATALOG level (set per-OpCo in the platform/ stack),
# which keeps each OpCo's data inside its own storage boundary rather than a
# shared metastore root. This is itself an ADR-worthy choice.
resource "databricks_metastore" "this" {
  name          = var.name
  region        = var.region
  force_destroy = var.force_destroy
}
