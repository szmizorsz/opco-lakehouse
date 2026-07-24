variable "subscription_id" {
  description = "Azure subscription that hosts the workspaces."
  type        = string
}

variable "databricks_account_id" {
  description = "Databricks account ID from the account console (1:1 with the Entra tenant)."
  type        = string
}

variable "region" {
  description = "Azure region for the metastore and workspaces. One metastore per region (ADR-0001)."
  type        = string
  default     = "westeurope"
}

variable "environments" {
  description = "Environments that each get their own workspace, all sharing the one regional metastore."
  type        = list(string)
  default     = ["dev", "uat", "prd"]
}

variable "resource_group_name" {
  description = "Resource group that holds the shared, per-env workspaces."
  type        = string
  default     = "rg-lkh-platform"
}
