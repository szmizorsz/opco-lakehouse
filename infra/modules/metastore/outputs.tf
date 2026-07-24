output "id" {
  description = "Metastore ID — consumed by the account stack (assignment) and passed to platform/."
  value       = databricks_metastore.this.id
}
