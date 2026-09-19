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

output "secondary_region" { value = var.secondary_location }
output "secondary_vnet_id" { value = module.secondary_vnet.id }
output "secondary_services_subnet_id" { value = module.secondary_services_subnet.id }
output "secondary_services_subnet_cidr" { value = module.secondary_services_subnet.address_prefixes }

output "services_subnet_id" {
  description = "Resource ID of the services subnet for future service VM Terraform."
  value       = module.services_subnet.id
}

output "platform_subnet_id" {
  description = "Resource ID of the platform subnet for future shared compute."
  value       = module.platform_subnet.id
}

output "api_management_subnet_id" {
  description = "Dedicated subnet ID used by staging API Management."
  value       = module.api_management_subnet.id
}

output "api_management_gateway_url" {
  description = "Public gateway base URL for the ASSMS frontend."
  value       = try(module.api_management[0].gateway_url, null)
}

output "database_subnet_id" {
  description = "Resource ID of the database subnet delegated for MySQL Flexible Server."
  value       = module.database_subnet.id
}

output "mysql_server_id" {
  description = "Resource ID of the shared MySQL server."
  value       = module.mysql.server_id
}

output "mysql_server_name" {
  description = "Name of the shared MySQL server."
  value       = module.mysql.server_name
}

output "mysql_fqdn" {
  description = "Private FQDN of the shared MySQL server."
  value       = module.mysql.fqdn
}

output "customer_database_name" {
  description = "Customer and Asset Service database name."
  value       = module.mysql.database_names["customerdb"]
}

output "job_database_name" {
  description = "Job Service database name."
  value       = module.mysql.database_names["jobdb"]
}

output "dispatch_database_name" {
  description = "Dispatch Service database name."
  value       = module.mysql.database_names["dispatchdb"]
}

output "reporting_database_name" {
  description = "Reporting Service database name."
  value       = module.mysql.database_names["reportingdb"]
}

output "kafka_vm_id" {
  description = "Resource ID of the Kafka VM."
  value       = module.kafka_vm.id
}

output "kafka_private_ip" {
  description = "Private IP address of the Kafka VM."
  value       = module.kafka_nic.private_ip_address
}

output "kafka_public_ip" {
  description = "Optional public IP address of the Kafka VM."
  value       = try(module.kafka_public_ip[0].ip_address, null)
}

output "kafka_bootstrap_server" {
  description = "Private Kafka bootstrap endpoint used by backend services."
  value       = "${module.kafka_nic.private_ip_address}:9092"
}
