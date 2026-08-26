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

This repository owns the shared network and shared platform infrastructure. The four service VMs and frontend hosting remain owned by their individual repositories.

## Shared Data and Messaging Infrastructure

The platform Terraform prepares a private MySQL Flexible Server in the delegated database subnet with `customerdb`, `jobdb`, `dispatchdb`, and `reportingdb`. Private DNS links MySQL to the ASSMS VNet; public MySQL access is disabled.

The Kafka VM is attached to the platform subnet. Kafka port 9092 and the future Prometheus/Grafana ports are reachable only from configured private ASSMS subnet ranges. Kafka software, Prometheus, and Grafana are intentionally not installed by Terraform. A public IP and SSH access are disabled by default and remain explicit configuration choices.
