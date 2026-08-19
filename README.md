# assms-platform-infrastructure

## Overview

## Responsibilities

## Technology

## Project Structure

## Local Development

## Environment Variables

## Testing

## Deployment

## Documentation

## Continuous Integration

Terraform changes are validated automatically through GitHub Actions.

Checks:
- terraform fmt
- terraform init -backend=false
- terraform validate

## Terraform Remote State Bootstrap

The bootstrap configuration initially uses local state because it creates the Azure Storage resources that will later hold remote Terraform state.

1. `az login`
2. `az account show`
3. `cd terraform/bootstrap/tfstate`
4. Copy `terraform.tfvars.example` to `terraform.tfvars`.
5. Provide a globally unique Azure Storage Account name.
6. `terraform init`
7. `terraform fmt -check`
8. `terraform validate`
9. `terraform plan`
10. `terraform apply`
