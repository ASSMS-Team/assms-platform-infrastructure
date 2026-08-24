variable "location" {
  description = "Azure region for the shared staging network."
  type        = string
  default     = "southeastasia"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "staging"
}

variable "resource_group_name" {
  description = "Name of the shared staging resource group."
  type        = string
  default     = "rg-assms-staging"
}

variable "vnet_name" {
  description = "Name of the shared staging virtual network."
  type        = string
  default     = "vnet-assms-staging"
}

variable "vnet_address_space" {
  description = "Address spaces assigned to the shared staging virtual network."
  type        = list(string)
  default     = ["10.20.0.0/16"]
}

variable "services_subnet_name" {
  description = "Name of the subnet reserved for future backend service VMs."
  type        = string
  default     = "snet-assms-services-staging"
}

variable "services_subnet_address_prefixes" {
  description = "Address prefixes for the services subnet."
  type        = list(string)
  default     = ["10.20.1.0/24"]
}

variable "platform_subnet_name" {
  description = "Name of the subnet reserved for future shared platform compute."
  type        = string
  default     = "snet-assms-platform-staging"
}

variable "platform_subnet_address_prefixes" {
  description = "Address prefixes for the platform subnet."
  type        = list(string)
  default     = ["10.20.2.0/24"]
}

variable "database_subnet_name" {
  description = "Name of the subnet reserved for future MySQL Flexible Server."
  type        = string
  default     = "snet-assms-database-staging"
}

variable "database_subnet_address_prefixes" {
  description = "Address prefixes for the database subnet."
  type        = list(string)
  default     = ["10.20.3.0/24"]
}

variable "database_subnet_delegation" {
  description = "Delegation that prepares the database subnet for MySQL Flexible Server."
  type = object({
    name = string
    service_delegation = object({
      name    = string
      actions = list(string)
    })
  })
  default = {
    name = "mysql-flexible-server"
    service_delegation = {
      name    = "Microsoft.DBforMySQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

variable "tags" {
  description = "Tags applied to shared staging resources."
  type        = map(string)
  default = {
    Project     = "ASSMS"
    Environment = "staging"
    ManagedBy   = "Terraform"
  }
}
