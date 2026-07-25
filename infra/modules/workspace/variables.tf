variable "name" {
  description = "Workspace name, e.g. adb-opco-dev."
  type        = string
}

variable "env" {
  description = "Environment this workspace serves (dev | uat | prd)."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that holds the workspace resource."
  type        = string
}

variable "location" {
  description = "Azure region — must match the metastore's region."
  type        = string
}
