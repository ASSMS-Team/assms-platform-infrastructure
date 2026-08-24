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

## Shared Staging Networking

The staging network creates a shared resource group and VNet with three private subnets:

- Services subnet: reserved for the four service repositories to provision their own VMs later.
- Platform subnet: reserved for future Kafka, monitoring, and other shared platform compute.
- Database subnet: prepared with MySQL Flexible Server delegation for a later database step.

This repository owns the shared network only. It does not create service VMs, public IPs, network security rules, databases, Kafka, monitoring, or application deployment.
