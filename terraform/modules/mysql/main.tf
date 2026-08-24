resource "azurerm_private_dns_zone" "mysql" {
  name                = var.private_dns_zone_name
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  name                  = var.private_dns_link_name
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.mysql.name
  virtual_network_id    = var.virtual_network_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_mysql_flexible_server" "this" {
  name                   = var.server_name
  resource_group_name    = var.resource_group_name
  location               = var.location
  administrator_login    = var.administrator_username
  administrator_password = var.administrator_password
  backup_retention_days  = var.backup_retention_days
  delegated_subnet_id    = var.delegated_subnet_id
  private_dns_zone_id    = azurerm_private_dns_zone.mysql.id
  public_network_access  = "Disabled"
  sku_name               = var.sku_name
  version                = var.mysql_version
  tags                   = var.tags

  storage {
    auto_grow_enabled = true
    size_gb           = var.storage_size_gb
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.mysql]
}

resource "azurerm_mysql_flexible_database" "this" {
  for_each = toset(var.database_names)

  name                = each.value
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.this.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}
