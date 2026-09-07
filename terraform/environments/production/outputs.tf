output "resource_group_name" {
  description = "Name of the shared production resource group."
  value       = module.resource_group.name
}
output "resource_group_id" {
  description = "Resource ID of the shared production resource group."
  value       = module.resource_group.id
}
output "vnet_name" {
  description = "Name of the shared production VNet."
  value       = module.vnet.name
}
output "vnet_id" {
  description = "Resource ID of the shared production VNet."
  value       = module.vnet.id
}
output "services_subnet_id" {
  description = "Resource ID of the production services subnet."
  value       = module.services_subnet.id
}
output "platform_subnet_id" {
  description = "Resource ID of the production platform subnet."
  value       = module.platform_subnet.id
}
output "database_subnet_id" {
  description = "Resource ID of the production database subnet."
  value       = module.database_subnet.id
}
output "mysql_server_id" {
  description = "Resource ID of production MySQL."
  value       = module.mysql.server_id
}
output "mysql_server_name" {
  description = "Name of production MySQL."
  value       = module.mysql.server_name
}
output "mysql_fqdn" {
  description = "Private FQDN of production MySQL."
  value       = module.mysql.fqdn
}
output "customer_database_name" {
  description = "Customer database name."
  value       = module.mysql.database_names["customerdb"]
}
output "job_database_name" {
  description = "Job database name."
  value       = module.mysql.database_names["jobdb"]
}
output "dispatch_database_name" {
  description = "Dispatch database name."
  value       = module.mysql.database_names["dispatchdb"]
}
output "reporting_database_name" {
  description = "Reporting database name."
  value       = module.mysql.database_names["reportingdb"]
}
output "kafka_vm_id" {
  description = "Resource ID of production Kafka."
  value       = module.kafka_vm.id
}
output "kafka_private_ip" {
  description = "Private IP of production Kafka."
  value       = module.kafka_nic.private_ip_address
}
output "kafka_public_ip" {
  description = "Optional public IP of production Kafka."
  value       = try(module.kafka_public_ip[0].ip_address, null)
}
output "kafka_bootstrap_server" {
  description = "Private Kafka bootstrap endpoint."
  value       = "${module.kafka_nic.private_ip_address}:9092"
}
