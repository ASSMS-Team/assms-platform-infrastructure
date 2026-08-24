output "server_id" {
  description = "Resource ID of the MySQL Flexible Server."
  value       = azurerm_mysql_flexible_server.this.id
}

output "server_name" {
  description = "Name of the MySQL Flexible Server."
  value       = azurerm_mysql_flexible_server.this.name
}

output "fqdn" {
  description = "Private FQDN of the MySQL Flexible Server."
  value       = azurerm_mysql_flexible_server.this.fqdn
}

output "database_names" {
  description = "Logical databases created on the shared MySQL server."
  value       = { for name, database in azurerm_mysql_flexible_database.this : name => database.name }
}

output "private_dns_zone_id" {
  description = "Resource ID of the MySQL private DNS zone."
  value       = azurerm_private_dns_zone.mysql.id
}
