variable "name" {
  description = "Name of the subnet."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group that contains the virtual network."
  type        = string
}

variable "virtual_network_name" {
  description = "Name of the virtual network that contains the subnet."
  type        = string
}

variable "address_prefixes" {
  description = "Address prefixes assigned to the subnet."
  type        = list(string)
}

variable "delegation" {
  description = "Optional Azure service delegation for the subnet."
  type = object({
    name = string
    service_delegation = object({
      name    = string
      actions = list(string)
    })
  })
  default  = null
  nullable = true
}
