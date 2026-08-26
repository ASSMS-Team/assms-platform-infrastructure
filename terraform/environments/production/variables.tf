variable "location" {
  description = "Azure region for the shared production infrastructure."
  type        = string
  default     = "southeastasia"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "production"
}

variable "resource_group_name" {
  description = "Name of the shared production resource group."
  type        = string
  default     = "rg-assms-production"
}

variable "vnet_name" {
  description = "Name of the shared production virtual network."
  type        = string
  default     = "vnet-assms-production"
}

variable "vnet_address_space" {
  description = "Address spaces assigned to the production VNet."
  type        = list(string)
  default     = ["10.30.0.0/16"]
}

variable "services_subnet_name" {
  description = "Name of the production services subnet."
  type        = string
  default     = "snet-assms-services-production"
}

variable "services_subnet_address_prefixes" {
  description = "Address prefixes for the production services subnet."
  type        = list(string)
  default     = ["10.30.1.0/24"]
}

variable "platform_subnet_name" {
  description = "Name of the production platform subnet."
  type        = string
  default     = "snet-assms-platform-production"
}

variable "platform_subnet_address_prefixes" {
  description = "Address prefixes for the production platform subnet."
  type        = list(string)
  default     = ["10.30.2.0/24"]
}

variable "database_subnet_name" {
  description = "Name of the production database subnet."
  type        = string
  default     = "snet-assms-database-production"
}

variable "database_subnet_address_prefixes" {
  description = "Address prefixes for the production database subnet."
  type        = list(string)
  default     = ["10.30.3.0/24"]
}

variable "database_subnet_delegation" {
  description = "Delegation for MySQL Flexible Server."
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

variable "mysql_server_name" {
  description = "Globally unique production MySQL server name."
  type        = string
}

variable "mysql_admin_username" {
  description = "Administrator username for production MySQL."
  type        = string
  default     = "assmsadmin"
}

variable "mysql_admin_password" {
  description = "Administrator password for production MySQL."
  type        = string
  sensitive   = true
}

variable "mysql_version" {
  description = "MySQL engine version."
  type        = string
  default     = "8.0.21"
}

variable "mysql_sku_name" {
  description = "Production MySQL SKU."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "mysql_storage_size_gb" {
  description = "Allocated MySQL storage in GiB."
  type        = number
  default     = 20
}

variable "mysql_backup_retention_days" {
  description = "MySQL backup retention in days."
  type        = number
  default     = 7
}

variable "mysql_private_dns_zone_name" {
  description = "Private DNS zone used by production MySQL."
  type        = string
  default     = "assms-production.mysql.database.azure.com"
}

variable "mysql_private_dns_link_name" {
  description = "Name of the production MySQL private DNS VNet link."
  type        = string
  default     = "pdnslink-assms-mysql-production"
}

variable "mysql_database_names" {
  description = "Logical ASSMS production databases."
  type        = list(string)
  default     = ["customerdb", "jobdb", "dispatchdb", "reportingdb"]
}

variable "kafka_vm_name" {
  description = "Name of the production Kafka VM."
  type        = string
  default     = "vm-assms-kafka-production"
}

variable "kafka_vm_size" {
  description = "Azure VM size for production Kafka."
  type        = string
  default     = "Standard_B2s"
}

variable "kafka_admin_username" {
  description = "Administrator username for the Kafka VM."
  type        = string
  default     = "assmsadmin"
}

variable "kafka_ssh_public_key" {
  description = "SSH public key used to administer the Kafka VM."
  type        = string
}

variable "kafka_nsg_name" {
  description = "Name of the Kafka VM NSG."
  type        = string
  default     = "nsg-assms-kafka-production"
}

variable "kafka_nic_name" {
  description = "Name of the Kafka VM NIC."
  type        = string
  default     = "nic-assms-kafka-production"
}

variable "kafka_public_ip_name" {
  description = "Name of the optional Kafka public IP."
  type        = string
  default     = "pip-assms-kafka-production"
}

variable "kafka_enable_public_ip" {
  description = "Whether to create a public IP for Kafka."
  type        = bool
  default     = false
}

variable "kafka_enable_ssh" {
  description = "Whether to allow SSH from approved CIDRs."
  type        = bool
  default     = false
  validation {
    condition     = !var.kafka_enable_ssh || length(var.kafka_ssh_allowed_source_cidrs) > 0
    error_message = "At least one SSH source CIDR is required when SSH is enabled."
  }
}

variable "kafka_ssh_allowed_source_cidrs" {
  description = "CIDRs permitted to SSH to Kafka."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for cidr in var.kafka_ssh_allowed_source_cidrs : cidr != "0.0.0.0/0"])
    error_message = "Unrestricted SSH from 0.0.0.0/0 is not permitted."
  }
}

variable "tags" {
  description = "Tags applied to shared production resources."
  type        = map(string)
  default = {
    Project     = "ASSMS"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
