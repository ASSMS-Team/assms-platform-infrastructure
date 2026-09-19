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

- [Terraform Staging Platform Deployment and Runbook](docs/deployment/terraform-staging-platform.md)

## Continuous Integration

Terraform changes are validated automatically through GitHub Actions on pull requests targeting `dev` or `main` and pushes to `dev` or `main`.

Checks:
- terraform fmt
- terraform init -backend=false
- terraform validate

Formatting or validation failures fail CI. This workflow does not deploy infrastructure or use Azure credentials.

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

The Kafka VM is attached to the platform subnet. Kafka port 9092 is reachable only from the private services subnet. Prometheus/Grafana access on ports 9090 and 3000 is postponed to ASSMS-18 and is not currently allowed by the Kafka NSG. Kafka software, Prometheus, and Grafana are intentionally not installed by Terraform. A public IP and SSH access are disabled by default and remain explicit configuration choices.

## API Management gateway

Sprint 2 adds Azure API Management as the single browser-facing route to the
Customer & Asset, Job, Dispatch and Reporting services. The gateway owns no
business data and forwards to service-owned HTTPS backends through `/customer`,
`/jobs`, `/dispatch` and `/reports` prefixes. See [the APIM gateway runbook](docs/deployment/api-management-gateway.md).

## Local Kafka Development

The local development foundation runs a single Apache Kafka broker in KRaft mode with Docker Compose. See [Local Kafka Development](docs/kafka/local-development.md) for startup, topic initialization, smoke testing, and consumer-group guidance.
