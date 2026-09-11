module "resource_group" {
  source = "../../modules/resource_group"

  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "vnet" {
  source = "../../modules/vnet"

  name                = var.vnet_name
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  address_space       = var.vnet_address_space
  tags                = var.tags
}

module "services_subnet" {
  source = "../../modules/subnet"

  name                 = var.services_subnet_name
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.vnet.name
  address_prefixes     = var.services_subnet_address_prefixes
}

module "platform_subnet" {
  source = "../../modules/subnet"

  name                 = var.platform_subnet_name
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.vnet.name
  address_prefixes     = var.platform_subnet_address_prefixes
}

# API Management has its own subnet. It must never share the platform, service
# or database subnets because VNet-injected APIM reserves addresses for its
# gateway and management components.
module "api_management_subnet" {
  source = "../../modules/subnet"

  name                 = var.api_management_subnet_name
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.vnet.name
  address_prefixes     = var.api_management_subnet_address_prefixes
}

# Classic Developer-tier APIM injected into a VNet requires an NSG. These
# rules implement the required external gateway and management-plane traffic
# and the Azure dependencies described by Microsoft for APIM VNet injection.
locals {
  api_management_security_rules = {
    AllowHttpsFromInternet = {
      priority                     = 100
      direction                    = "Inbound"
      access                       = "Allow"
      protocol                     = "Tcp"
      destination_port_ranges      = ["443"]
      source_address_prefixes      = ["Internet"]
      destination_address_prefixes = ["VirtualNetwork"]
      description                  = "Allow HTTPS client traffic to the external APIM gateway."
    }
    AllowApimManagementPlane = {
      priority                     = 110
      direction                    = "Inbound"
      access                       = "Allow"
      protocol                     = "Tcp"
      destination_port_ranges      = ["3443"]
      source_address_prefixes      = ["ApiManagement"]
      destination_address_prefixes = ["VirtualNetwork"]
      description                  = "Allow the Azure API Management control plane."
    }
    AllowAzureLoadBalancerHealthProbe = {
      priority                     = 120
      direction                    = "Inbound"
      access                       = "Allow"
      protocol                     = "Tcp"
      destination_port_ranges      = ["6390"]
      source_address_prefixes      = ["AzureLoadBalancer"]
      destination_address_prefixes = ["VirtualNetwork"]
      description                  = "Allow Azure Load Balancer health probes for the APIM subnet."
    }
    AllowCertificateValidation = {
      priority                     = 100
      direction                    = "Outbound"
      access                       = "Allow"
      protocol                     = "Tcp"
      destination_port_ranges      = ["80"]
      source_address_prefixes      = ["VirtualNetwork"]
      destination_address_prefixes = ["Internet"]
      description                  = "Allow certificate validation and APIM management dependencies."
    }
    AllowStorage = {
      priority                     = 110
      direction                    = "Outbound"
      access                       = "Allow"
      protocol                     = "Tcp"
      destination_port_ranges      = ["443"]
      source_address_prefixes      = ["VirtualNetwork"]
      destination_address_prefixes = ["Storage"]
      description                  = "Allow the Azure Storage dependency required by APIM."
    }
    AllowAzureActiveDirectory = {
      priority                     = 120
      direction                    = "Outbound"
      access                       = "Allow"
      protocol                     = "Tcp"
      destination_port_ranges      = ["443"]
      source_address_prefixes      = ["VirtualNetwork"]
      destination_address_prefixes = ["AzureActiveDirectory"]
      description                  = "Allow Microsoft Entra ID dependencies used by APIM."
    }
    AllowAzureMonitor = {
      priority                     = 130
      direction                    = "Outbound"
      access                       = "Allow"
      protocol                     = "Tcp"
      destination_port_ranges      = ["443", "1886"]
      source_address_prefixes      = ["VirtualNetwork"]
      destination_address_prefixes = ["AzureMonitor"]
      description                  = "Allow APIM diagnostics, metrics and resource health."
    }
  }
}

module "api_management_nsg" {
  source = "../../modules/nsg"

  name                = var.api_management_nsg_name
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  security_rules      = local.api_management_security_rules
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "api_management" {
  subnet_id                 = module.api_management_subnet.id
  network_security_group_id = module.api_management_nsg.id

  depends_on = [module.api_management_nsg]
}

module "database_subnet" {
  source = "../../modules/subnet"

  name                 = var.database_subnet_name
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.vnet.name
  address_prefixes     = var.database_subnet_address_prefixes
  delegation           = var.database_subnet_delegation
}

module "secondary_vnet" {
  source = "../../modules/vnet"

  name                = var.secondary_vnet_name
  resource_group_name = module.resource_group.name
  location            = var.secondary_location
  address_space       = var.secondary_vnet_address_space
  tags                = var.tags
}

module "secondary_services_subnet" {
  source = "../../modules/subnet"

  name                 = var.secondary_services_subnet_name
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.secondary_vnet.name
  address_prefixes     = var.secondary_services_subnet_address_prefixes
}

resource "azurerm_virtual_network_peering" "primary_to_secondary" {
  name                         = var.primary_to_secondary_peering_name
  resource_group_name          = module.resource_group.name
  virtual_network_name         = module.vnet.name
  remote_virtual_network_id    = module.secondary_vnet.id
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "secondary_to_primary" {
  name                         = var.secondary_to_primary_peering_name
  resource_group_name          = module.resource_group.name
  virtual_network_name         = module.secondary_vnet.name
  remote_virtual_network_id    = module.vnet.id
  allow_virtual_network_access = true
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql_secondary" {
  name                  = var.mysql_secondary_private_dns_link_name
  resource_group_name   = module.resource_group.name
  private_dns_zone_name = var.mysql_private_dns_zone_name
  virtual_network_id    = module.secondary_vnet.id
  registration_enabled  = false
  tags                  = var.tags

  depends_on = [module.mysql]
}

module "mysql" {
  source = "../../modules/mysql"

  server_name               = var.mysql_server_name
  resource_group_name       = module.resource_group.name
  location                  = module.resource_group.location
  delegated_subnet_id       = module.database_subnet.id
  virtual_network_id        = module.vnet.id
  private_dns_zone_name     = var.mysql_private_dns_zone_name
  private_dns_link_name     = var.mysql_private_dns_link_name
  administrator_username    = var.mysql_admin_username
  administrator_password    = var.mysql_admin_password
  mysql_version             = var.mysql_version
  sku_name                  = var.mysql_sku_name
  storage_size_gb           = var.mysql_storage_size_gb
  storage_auto_grow_enabled = var.mysql_storage_auto_grow_enabled
  backup_retention_days     = var.mysql_backup_retention_days
  database_names            = var.mysql_database_names
  tags                      = var.tags
}

locals {
  kafka_security_rules = merge(
    {
      AllowKafkaFromServicesSubnet = {
        priority                = 1001
        direction               = "Inbound"
        access                  = "Allow"
        protocol                = "Tcp"
        destination_port_ranges = ["9092"]
        source_address_prefixes = concat(var.services_subnet_address_prefixes, var.secondary_services_subnet_address_prefixes)
        description             = "Allow Kafka clients from the private services subnet."
      }
    },
    var.kafka_enable_ssh ? {
      AllowSshFromApprovedCidrs = {
        priority                = 1000
        direction               = "Inbound"
        access                  = "Allow"
        protocol                = "Tcp"
        destination_port_ranges = ["22"]
        source_address_prefixes = var.kafka_ssh_allowed_source_cidrs
        description             = "Allow SSH only from explicitly approved administrator CIDRs."
      }
    } : {}
  )
}

module "kafka_nsg" {
  source = "../../modules/nsg"

  name                = var.kafka_nsg_name
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  security_rules      = local.kafka_security_rules
  tags                = var.tags
}

module "kafka_public_ip" {
  count  = var.kafka_enable_public_ip ? 1 : 0
  source = "../../modules/public_ip"

  name                = var.kafka_public_ip_name
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  tags                = var.tags
}

module "kafka_nic" {
  source = "../../modules/nic"

  name                      = var.kafka_nic_name
  resource_group_name       = module.resource_group.name
  location                  = module.resource_group.location
  subnet_id                 = module.platform_subnet.id
  network_security_group_id = module.kafka_nsg.id
  public_ip_id              = try(module.kafka_public_ip[0].id, null)
  tags                      = var.tags
}

module "kafka_vm" {
  source = "../../modules/kafka_vm"

  name                 = var.kafka_vm_name
  resource_group_name  = module.resource_group.name
  location             = module.resource_group.location
  size                 = var.kafka_vm_size
  admin_username       = var.kafka_admin_username
  ssh_public_key       = var.kafka_ssh_public_key
  network_interface_id = module.kafka_nic.id
  source_image_sku     = var.kafka_source_image_sku
  tags                 = var.tags
}

module "api_management" {
  source = "../../modules/api_management"

  name                 = var.api_management_name
  location             = module.resource_group.location
  resource_group_name  = module.resource_group.name
  publisher_name       = var.api_management_publisher_name
  publisher_email      = var.api_management_publisher_email
  sku_name             = var.api_management_sku_name
  virtual_network_type = var.api_management_virtual_network_type
  subnet_id            = module.api_management_subnet.id
  frontend_origin      = var.api_management_frontend_origin
  backend_apis         = var.api_management_backend_apis
  tags                 = var.tags

  depends_on = [azurerm_subnet_network_security_group_association.api_management]
}
