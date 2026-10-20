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

variable "existing_metastore_id" {
  description = <<-EOT
    Reuse an existing regional metastore instead of creating one. In a shared account the
    region's metastore already exists (ADR-0001: one metastore per region), so set this to
    its metastore_id. Leave "" to create a new metastore (fresh region / clean sandbox).
  EOT
  type        = string
  default     = ""
}

variable "resource_group_name" {
  description = "Resource group that holds the shared, per-env workspaces."
  type        = string
  default     = "rg-opco-platform"
}

variable "cost_center" {
  description = "Datapao CostCenter tag — Azure Policy requires it on every resource group."
  type        = string
  default     = "paodemos"
}

variable "resource_group_owner" {
  description = "ResourceGroupOwner tag — a <first.last>@datapao.com account (Azure Policy)."
  type        = string
}
