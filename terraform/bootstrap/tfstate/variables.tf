variable "location" {
  description = "Azure region for the Terraform state resources."
  type        = string
  default     = "southeastasia"
}

variable "resource_group_name" {
  description = "Name of the Azure resource group that contains Terraform state resources."
  type        = string
  default     = "rg-assms-tfstate"
}

variable "storage_account_name" {
  description = "Globally unique Azure Storage Account name for Terraform state."
  type        = string
}

variable "container_name" {
  description = "Name of the private blob container used for Terraform state files."
  type        = string
  default     = "tfstate"
}
