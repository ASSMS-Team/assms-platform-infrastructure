variable "name" {
  description = "Name of the network interface."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group."
  type        = string
}

variable "location" {
  description = "Azure region for the network interface."
  type        = string
}

variable "subnet_id" {
  description = "Resource ID of the subnet."
  type        = string
}

variable "network_security_group_id" {
  description = "Resource ID of the NSG associated with the NIC."
  type        = string
}

variable "public_ip_id" {
  description = "Optional public IP resource ID."
  type        = string
  default     = null
  nullable    = true
}

variable "tags" {
  description = "Tags applied to the NIC."
  type        = map(string)
  default     = {}
}
