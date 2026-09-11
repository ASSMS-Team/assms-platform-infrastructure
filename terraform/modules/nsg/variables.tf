variable "name" {
  description = "Name of the network security group."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group containing the NSG."
  type        = string
}

variable "location" {
  description = "Azure region for the NSG."
  type        = string
}

variable "security_rules" {
  description = "Network security rules keyed by rule name."
  type = map(object({
    priority                     = number
    direction                    = string
    access                       = string
    protocol                     = string
    destination_port_ranges      = list(string)
    source_address_prefix        = optional(string)
    source_address_prefixes      = optional(list(string))
    destination_address_prefix   = optional(string)
    destination_address_prefixes = optional(list(string), ["*"])
    description                  = string
  }))
  default = {}
}

variable "tags" {
  description = "Tags applied to the NSG."
  type        = map(string)
  default     = {}
}
