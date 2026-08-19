output "resource_group_name" {
  description = "Name of the Terraform state resource group."
  value       = azurerm_resource_group.tfstate.name
}

output "storage_account_name" {
  description = "Name of the Terraform state Storage Account."
  value       = azurerm_storage_account.tfstate.name
}

output "storage_account_id" {
  description = "Resource ID of the Terraform state Storage Account."
  value       = azurerm_storage_account.tfstate.id
}

output "container_name" {
  description = "Name of the private Terraform state blob container."
  value       = azurerm_storage_container.tfstate.name
}
