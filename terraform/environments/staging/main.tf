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

module "database_subnet" {
  source = "../../modules/subnet"

  name                 = var.database_subnet_name
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.vnet.name
  address_prefixes     = var.database_subnet_address_prefixes
  delegation           = var.database_subnet_delegation
}
