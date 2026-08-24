variable "name" {
  description = "Name of the Kafka Linux VM."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the shared platform resource group."
  type        = string
}

variable "location" {
  description = "Azure region for the Kafka VM."
  type        = string
}

variable "size" {
  description = "Azure VM size for the Kafka host."
  type        = string
}

variable "admin_username" {
  description = "Administrator username for the Kafka VM."
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key used to administer the Kafka VM."
  type        = string
}

variable "network_interface_id" {
  description = "Resource ID of the Kafka VM network interface."
  type        = string
}

variable "tags" {
  description = "Tags applied to the Kafka VM."
  type        = map(string)
  default     = {}
}
