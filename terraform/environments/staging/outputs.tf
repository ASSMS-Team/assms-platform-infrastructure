output "resource_group_name" {
  description = "Name of the shared staging resource group."
  value       = module.resource_group.name
}

output "resource_group_id" {
  description = "Resource ID of the shared staging resource group."
  value       = module.resource_group.id
}

output "vnet_name" {
  description = "Name of the shared staging virtual network."
  value       = module.vnet.name
}

output "vnet_id" {
  description = "Resource ID of the shared staging virtual network."
  value       = module.vnet.id
}

output "services_subnet_id" {
  description = "Resource ID of the services subnet for future service VM Terraform."
  value       = module.services_subnet.id
}

output "platform_subnet_id" {
  description = "Resource ID of the platform subnet for future shared compute."
  value       = module.platform_subnet.id
}

output "database_subnet_id" {
  description = "Resource ID of the database subnet delegated for MySQL Flexible Server."
  value       = module.database_subnet.id
}
