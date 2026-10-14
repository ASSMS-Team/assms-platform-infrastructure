variable "github_oidc_enabled" {
  description = "Create the Azure identity used by ASSMS staging deployments."
  type        = bool
  default     = false
}

variable "github_oidc_organization" {
  type    = string
  default = "ASSMS-Team"
}

variable "github_oidc_repositories" {
  type = set(string)
  default = [
    "assms-platform-infrastructure",
    "assms-customer-asset-service",
    "assms-job-service",
    "assms-dispatch-service",
    "assms-reporting-service",
    "assms-frontend",
  ]
}

variable "github_oidc_subjects" {
  description = "Exact dev-branch OIDC subjects, including immutable IDs where enabled by GitHub."
  type        = map(string)
  default     = {}
}

resource "azurerm_user_assigned_identity" "github_cd" {
  count = var.github_oidc_enabled ? 1 : 0

  name                = "id-assms-github-staging-cd"
  resource_group_name = module.resource_group.name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "github_dev" {
  for_each = var.github_oidc_enabled ? var.github_oidc_repositories : toset([])

  name      = "github-${each.value}-dev"
  parent_id = azurerm_user_assigned_identity.github_cd[0].id
  audience  = ["api://AzureADTokenExchange"]
  issuer    = "https://token.actions.githubusercontent.com"
  subject   = lookup(var.github_oidc_subjects, each.value, "repo:${var.github_oidc_organization}/${each.value}:ref:refs/heads/dev")
}

output "github_cd_client_id" {
  value = try(azurerm_user_assigned_identity.github_cd[0].client_id, null)
}

output "github_cd_principal_id" {
  value = try(azurerm_user_assigned_identity.github_cd[0].principal_id, null)
}
