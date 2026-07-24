output "workspace_id" {
  description = "Numeric workspace ID, used for metastore assignment."
  value       = azurerm_databricks_workspace.this.workspace_id
}

output "workspace_url" {
  description = "Workspace host (the workspace-host databricks provider points here in platform/)."
  value       = "https://${azurerm_databricks_workspace.this.workspace_url}"
}

output "resource_id" {
  description = "ARM resource ID of the Microsoft.Databricks/workspaces resource."
  value       = azurerm_databricks_workspace.this.id
}
