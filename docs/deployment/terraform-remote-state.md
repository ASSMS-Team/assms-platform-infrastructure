# Terraform Remote State

ASSMS Terraform state is remote and separated by repository.

| Item | Value |
|---|---|
| Resource group | `rg-assms-tfstate` |
| Storage account | `stassmstfstate45ff260826` |
| Container | `tfstate` |

State keys are `platform/staging.tfstate`, `customer-asset-service/staging.tfstate`, `job-service/staging.tfstate`, `dispatch-service/staging.tfstate`, `reporting-service/staging.tfstate`, and `frontend/staging.tfstate`.

Never commit `terraform.tfstate`, real `terraform.tfvars`, `backend.hcl`, `.terraform/`, saved plans, credentials, or keys. Save plans only for review/apply of the exact current state, then delete them after a successful apply.
