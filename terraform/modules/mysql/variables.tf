variable "server_name" {
  description = "Globally unique name of the MySQL Flexible Server."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the shared platform resource group."
  type        = string
}

variable "location" {
  description = "Azure region for the MySQL server."
  type        = string
}

variable "delegated_subnet_id" {
  description = "Resource ID of the delegated database subnet."
  type        = string
}

variable "virtual_network_id" {
  description = "Resource ID of the shared virtual network."
  type        = string
}

variable "private_dns_zone_name" {
  description = "Private DNS zone name used by MySQL Flexible Server."
  type        = string
}

variable "private_dns_link_name" {
  description = "Name of the private DNS zone link to the ASSMS VNet."
  type        = string
}

variable "administrator_username" {
  description = "Administrator username for MySQL Flexible Server."
  type        = string
}

variable "administrator_password" {
  description = "Administrator password for MySQL Flexible Server."
  type        = string
  sensitive   = true
}

variable "mysql_version" {
  description = "MySQL engine version."
  type        = string
}

variable "sku_name" {
  description = "Azure MySQL Flexible Server SKU."
  type        = string
}

variable "storage_size_gb" {
  description = "Allocated MySQL storage in GiB."
  type        = number
}

variable "storage_auto_grow_enabled" {
  description = "Whether MySQL storage can grow automatically when capacity is low."
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days MySQL backups are retained."
  type        = number
}

variable "database_names" {
  description = "Logical database names created on the shared server."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to MySQL and private DNS resources."
  type        = map(string)
  default     = {}
}
