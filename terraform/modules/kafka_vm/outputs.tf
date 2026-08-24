output "id" {
  description = "Resource ID of the Kafka VM."
  value       = azurerm_linux_virtual_machine.this.id
}

output "name" {
  description = "Name of the Kafka VM."
  value       = azurerm_linux_virtual_machine.this.name
}
