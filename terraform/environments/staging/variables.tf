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

variable "mysql_server_name" {
  description = "Globally unique name of the staging MySQL Flexible Server."
  type        = string
}

variable "mysql_admin_username" {
  description = "Administrator username for the staging MySQL server."
  type        = string
  default     = "assmsadmin"
}

variable "mysql_admin_password" {
  description = "Administrator password for the staging MySQL server."
  type        = string
  sensitive   = true
}

variable "mysql_version" {
  description = "MySQL engine version."
  type        = string
  default     = "8.0.21"
}

variable "mysql_sku_name" {
  description = "Staging MySQL SKU."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "mysql_storage_size_gb" {
  description = "Allocated MySQL storage in GiB."
  type        = number
  default     = 20
}

variable "mysql_storage_auto_grow_enabled" {
  description = "Whether staging MySQL storage can grow automatically when capacity is low."
  type        = bool
  default     = false
}

variable "mysql_backup_retention_days" {
  description = "MySQL backup retention in days."
  type        = number
  default     = 7
}

variable "mysql_private_dns_zone_name" {
  description = "Private DNS zone used by staging MySQL."
  type        = string
  default     = "assms-staging.mysql.database.azure.com"
}

variable "mysql_private_dns_link_name" {
  description = "Name of the MySQL private DNS VNet link."
  type        = string
  default     = "pdnslink-assms-mysql-staging"
}

variable "mysql_database_names" {
  description = "Logical ASSMS databases on the shared server."
  type        = list(string)
  default     = ["customerdb", "jobdb", "dispatchdb", "reportingdb"]
}

variable "kafka_vm_name" {
  description = "Name of the staging Kafka VM."
  type        = string
  default     = "vm-assms-kafka-staging"
}

variable "kafka_vm_size" {
  description = "Azure VM size for the staging Kafka host."
  type        = string
  default     = "Standard_B2pls_v2"
}

variable "kafka_source_image_sku" {
  description = "Canonical Ubuntu Arm64 image SKU for the staging Kafka VM."
  type        = string
  default     = "22_04-lts-arm64"
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
  default     = "nsg-assms-kafka-staging"
}

variable "kafka_nic_name" {
  description = "Name of the Kafka VM NIC."
  type        = string
  default     = "nic-assms-kafka-staging"
}

variable "kafka_public_ip_name" {
  description = "Name of the optional Kafka public IP."
  type        = string
  default     = "pip-assms-kafka-staging"
}

variable "kafka_enable_public_ip" {
  description = "Whether to create a public IP for the Kafka VM."
  type        = bool
  default     = false
}
variable "kafka_enable_ssh" {
  description = "Whether to allow SSH from explicitly approved CIDRs."
  type        = bool
  default     = false
  validation {
    condition     = !var.kafka_enable_ssh || length(var.kafka_ssh_allowed_source_cidrs) > 0
    error_message = "At least one approved SSH source CIDR is required when Kafka SSH is enabled."
  }
}
variable "kafka_ssh_allowed_source_cidrs" {
  description = "CIDRs permitted to SSH to Kafka when SSH is enabled."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for cidr in var.kafka_ssh_allowed_source_cidrs : cidr != "0.0.0.0/0"])
    error_message = "Unrestricted SSH from 0.0.0.0/0 is not permitted."
  }
}
