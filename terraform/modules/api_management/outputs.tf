output "id" {
  description = "Resource ID of the API Management service."
  value       = azurerm_api_management.this.id
}

output "name" {
  description = "Name of the API Management service."
  value       = azurerm_api_management.this.name
}

output "gateway_url" {
  description = "Public HTTPS base URL of the managed gateway."
  value       = azurerm_api_management.this.gateway_url
}
