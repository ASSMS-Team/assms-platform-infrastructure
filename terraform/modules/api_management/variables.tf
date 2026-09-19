variable "name" {
  type        = string
  description = "Globally unique API Management service name."
}

variable "location" {
  type        = string
  description = "Azure region for API Management; it must match the VNet region."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group that owns the API Management service."
}

variable "publisher_name" {
  type        = string
  description = "Display name presented by the API Management developer portal."
}

variable "publisher_email" {
  type        = string
  description = "Operations contact email required by Azure API Management."
}

variable "sku_name" {
  type        = string
  description = "API Management SKU, for example Developer_1 for staging."
  default     = "Developer_1"
}

variable "virtual_network_type" {
  type        = string
  description = "Classic APIM VNet mode. External exposes the gateway while reaching private backends."
  default     = "External"

  validation {
    condition     = contains(["External", "Internal", "None"], var.virtual_network_type)
    error_message = "virtual_network_type must be External, Internal or None."
  }
}

variable "subnet_id" {
  type        = string
  description = "Dedicated subnet ID for API Management VNet injection."
}

variable "frontend_origin" {
  type        = string
  description = "Exact HTTPS frontend origin permitted by the APIM CORS policy."
}

variable "backend_apis" {
  description = "Gateway prefixes and HTTPS backend origins owned by the service repositories."
  type = map(object({
    display_name = string
    path         = string
    url          = string
  }))

  validation {
    condition     = alltrue([for api in values(var.backend_apis) : startswith(api.url, "https://") && !endswith(api.url, "/")])
    error_message = "Every backend URL must be HTTPS and must not end in a slash."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to API Management."
  default     = {}
}
