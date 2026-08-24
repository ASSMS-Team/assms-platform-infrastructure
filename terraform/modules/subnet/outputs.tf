output "id" {
  description = "Resource ID of the subnet."
  value       = azurerm_subnet.this.id
}

output "name" {
  description = "Name of the subnet."
  value       = azurerm_subnet.this.name
}

output "address_prefixes" {
  description = "Address prefixes assigned to the subnet."
  value       = azurerm_subnet.this.address_prefixes
}
