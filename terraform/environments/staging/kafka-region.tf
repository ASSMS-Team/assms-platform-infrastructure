variable "kafka_location" {
  description = "Optional separate Kafka region. Null preserves the existing primary-region layout."
  type        = string
  default     = null
}

variable "kafka_vnet_name" {
  type    = string
  default = "vnet-assms-kafka-staging"
}

variable "kafka_vnet_address_space" {
  type    = list(string)
  default = ["10.40.0.0/16"]
}

variable "kafka_subnet_name" {
  type    = string
  default = "snet-assms-kafka-staging"
}

variable "kafka_subnet_address_prefixes" {
  type    = list(string)
  default = ["10.40.2.0/24"]
}

output "kafka_region" {
  value = local.kafka_region
}
