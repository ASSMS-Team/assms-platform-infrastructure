variable "name" {
  description = "Name of the public IP resource."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group."
  type        = string
}

variable "location" {
  description = "Azure region for the public IP."
  type        = string
}

variable "tags" {
  description = "Tags applied to the public IP."
  type        = map(string)
  default     = {}
}
