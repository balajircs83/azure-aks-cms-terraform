variable "resource_group_name" {
  default = "cms-rg-poc"
}

variable "location" {
  default = "East US 2"
}

variable "aks_cluster_name" {
  default = "cms-aks-cluster"
}

variable "acr_name" {
  default = "cmsacr2025" # Must be globally unique
}

variable "sql_server_name" {
  default = "cms-sql-server2025" # Must be globally unique
}

variable "sql_admin_username" {
  default = "sqladmin"
}

variable "sql_admin_password" {
  default = "P@ssw0rd123!" # Replace with a secure password
}


variable "owner_name" {
  description = "Name of the resource owner"
  type        = string
}

variable "owner_phone_email" {
  description = "Contact info (phone or email) of the owner"
  type        = string
}

variable "poc_name" {
  description = "Name of the point of contact"
  type        = string
}

variable "approver" {
  description = "Name of the approver"
  type        = string
}

variable "valid_till_date" {
  description = "Date until which the resources are valid (e.g., YYYY-MM-DD)"
  type        = string
}