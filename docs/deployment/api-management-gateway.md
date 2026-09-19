# Azure API Management gateway

## Purpose

Sprint 2 exposes ASSMS backend APIs through one managed public gateway instead
of giving the React application four independent service addresses. The gateway
does not own customer, job, dispatch or reporting data; it only routes browser
requests to the service that owns each API.

```text
React frontend
    |
    v
Azure API Management
    |-- /customer/api/... --> Customer & Asset Service
    |-- /jobs/api/...     --> Job Service
    |-- /dispatch/api/... --> Dispatch Service
    '-- /reports/api/...  --> Reporting Service
```

## Terraform ownership

`terraform/environments/staging` creates a dedicated `/27` APIM subnet and the
Developer-tier staging instance through `modules/api_management`. The module
creates one API per service, a pass-through operation for the existing
`/api/...` routes, CORS for the exact frontend origin, and an
`X-Correlation-ID` header.

The four backend URLs are inputs because their VMs are owned and deployed by
their respective repositories. Values must be HTTPS origins without a trailing
slash. Do not use localhost, a private database endpoint, Kafka, or a secret as
a backend URL.

## Authentication boundary

The gateway forwards the browser's `Authorization: Bearer` header. It does not
hold the shared HMAC JWT signing key, and it does not replace backend JWT or
role checks. Customer & Asset, Job, Dispatch and Reporting remain the
authorization boundary for their own operations.

## Frontend configuration

After deployment, set a single `VITE_API_BASE_URL` to the APIM `gateway_url`.
The frontend service base URLs become:

| Service | Base URL |
|---|---|
| Customer & Asset | `${VITE_API_BASE_URL}/customer` |
| Job | `${VITE_API_BASE_URL}/jobs` |
| Dispatch | `${VITE_API_BASE_URL}/dispatch` |
| Reporting | `${VITE_API_BASE_URL}/reports` |

The frontend change belongs in its own repository branch so the platform and
frontend commits retain their independent ownership.

## Deployment and verification

1. Copy the APIM values from `terraform.tfvars.example` into a secure local
   `terraform.tfvars`; use actual staging service HTTPS origins.
2. Run `terraform fmt -check`, `terraform init -backend=false`, `terraform
   validate`, then review `terraform plan`. Do not apply until the team reviews
   cost, the chosen SKU and the backend origins.
3. Deploy APIM and record its `api_management_gateway_url` output.
4. Deploy the frontend with its APIM base URL.
5. Sign in, call one protected Dispatch endpoint through APIM, and verify that
   the backend still rejects a missing or insufficient JWT.

This document records Terraform configuration only. It does not claim that APIM
or any gateway route is deployed until that final staging request succeeds.
