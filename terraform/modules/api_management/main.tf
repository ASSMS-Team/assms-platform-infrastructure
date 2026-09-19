resource "azurerm_api_management" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = var.sku_name

  # External mode keeps the gateway publicly reachable by the React app while
  # allowing it to reach backend VMs through the shared staging VNet.
  virtual_network_type = var.virtual_network_type

  virtual_network_configuration {
    subnet_id = var.subnet_id
  }

  tags = var.tags
}

resource "azurerm_api_management_api" "service" {
  for_each = var.backend_apis

  name                = "${each.key}-v1"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.this.name
  revision            = "1"
  display_name        = each.value.display_name
  path                = each.value.path
  protocols           = ["https"]
  service_url         = trimsuffix(each.value.url, "/")

  # Staff JWTs, not APIM subscriptions, control access. Each backend continues
  # to validate the token and enforce its own role policies.
  subscription_required = false
}

locals {
  pass_through_methods = toset(["GET", "POST", "PUT", "PATCH", "DELETE"])
  pass_through_operations = {
    for pair in setproduct(keys(var.backend_apis), local.pass_through_methods) :
    "${pair[0]}-${lower(pair[1])}" => {
      api_key = pair[0]
      method  = pair[1]
    }
  }
}

# The wildcard operation keeps the backend's existing /api/... route shape.
# For example, /dispatch/api/technicians is forwarded as /api/technicians to
# the Dispatch Service. Swagger can later replace these generic operations with
# fine-grained imported operations without changing the public gateway prefixes.
resource "azurerm_api_management_api_operation" "pass_through" {
  for_each = local.pass_through_operations

  operation_id        = "${each.value.api_key}-${lower(each.value.method)}-pass-through"
  api_name            = azurerm_api_management_api.service[each.value.api_key].name
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name
  display_name        = "${each.value.method} ${each.value.api_key} pass-through"
  method              = each.value.method
  url_template        = "/*"
  description         = "Routes the existing backend API path through ASSMS API Management."
}

resource "azurerm_api_management_api_policy" "service" {
  for_each = var.backend_apis

  api_name            = azurerm_api_management_api.service[each.key].name
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name

  xml_content = templatefile("${path.module}/policy.xml.tftpl", {
    frontend_origin = var.frontend_origin
  })
}
