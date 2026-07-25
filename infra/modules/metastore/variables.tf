variable "name" {
  description = "Metastore name, e.g. opco-metastore-westeurope."
  type        = string
}

variable "region" {
  description = "Azure region. At most one metastore per region per account (ADR-0001)."
  type        = string
}

variable "force_destroy" {
  description = "Allow destroy even if catalogs still exist — true suits the ephemeral demo profile."
  type        = bool
  default     = true
}
