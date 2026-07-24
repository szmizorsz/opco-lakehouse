output "metastore_id" {
  description = "Passed to the platform/ stack as an input var (not via remote_state — ADR-0005)."
  value       = local.metastore_id
}

output "workspace_ids" {
  description = "Numeric workspace IDs, keyed by environment."
  value       = { for env, ws in module.workspace : env => ws.workspace_id }
}

output "workspace_urls" {
  description = "Workspace hosts, keyed by environment — the platform/ stack targets these."
  value       = { for env, ws in module.workspace : env => ws.workspace_url }
}
