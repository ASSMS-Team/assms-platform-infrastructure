# Sprint 1 Evaluation Evidence

This folder contains the consolidated Sprint 1 documents for ASSMS Group 25. The documents are version-controlled here because `F:\Projects\ASSMS` is only a workspace containing six independent repositories and is intentionally not a Git repository.

## Documents

- `ASSMS_Sprint_1_Requirements_and_Acceptance_Criteria.docx`
- `ASSMS_Sprint_1_Technical_Architecture.docx`
- `ASSMS_Sprint_1_API_Documentation_and_Swagger_Evidence.docx`
- `ASSMS_Sprint_1_Database_Schema_Tables_and_Migrations.docx`
- `ASSMS_Sprint_1_CI_CD_Workflow.docx`
- `ASSMS_Sprint_1_Azure_Deployment_and_Infrastructure.docx`
- `ASSMS_Sprint_1_Requirements_and_Acceptance_Criteria.pdf` — convenience preview

## Evaluation branch

Use each repository's remote `dev` branch for the Sprint 1 evaluation. At the repository check on 7 September 2026, Dispatch, Platform Infrastructure and Reporting contained Sprint 1 commits on `dev` that were not yet in `main`.

## GitHub Actions evidence checklist

The repositories are private, so an authenticated team member must capture these screenshots before the presentation. Do not mark a workflow successful based only on the presence of its YAML file.

| Repository | Required evidence | Actions page | Status |
|---|---|---|---|
| Customer & Asset | Latest successful `Customer Asset Service CI`; Terraform and .NET jobs; test artifact; staging CD if executed | <https://github.com/ASSMS-Team/assms-customer-asset-service/actions> | Capture required |
| Dispatch | Latest successful `Dispatch Service CI`; Terraform and .NET jobs; test artifact | <https://github.com/ASSMS-Team/assms-dispatch-service/actions> | Capture required |
| Frontend | Latest successful `Frontend CI`; Terraform, lint and build jobs; staging CD if executed | <https://github.com/ASSMS-Team/assms-frontend/actions> | Capture required |
| Job | Latest successful `Job Service CI`; Terraform and .NET jobs; test artifact; staging CD if executed | <https://github.com/ASSMS-Team/assms-job-service/actions> | Capture required |
| Platform Infrastructure | Latest successful `Terraform CI` run | <https://github.com/ASSMS-Team/assms-platform-infrastructure/actions> | Capture required |
| Reporting | Latest successful `Reporting Service CI`; Terraform and .NET jobs; test artifact; staging CD if executed | <https://github.com/ASSMS-Team/assms-reporting-service/actions> | Capture required |

For every screenshot, include the workflow name, green conclusion, branch, commit SHA and run date. For test artifacts, show the artifact name and retention entry. If a CD workflow has not completed successfully, describe it as implemented rather than verified.

## Repository verification recorded on 7 September 2026

- All six remote `dev` branches contain their expected CI workflows.
- Terraform formatting passed.
- All 13 Terraform roots validated successfully: bootstrap, staging and production roots across the six repositories.
- Frontend lint and production build passed.
- Local .NET execution was unavailable because the workstation had .NET SDK 10 while the repositories pin SDK 8.0.424. The corresponding GitHub Actions runs are the required test evidence.
- No credentials or private keys are included in this evidence folder.

## Honest Sprint 1 boundary

The project provides a production-oriented foundation and recorded staging deployment evidence. It does not claim that production is deployed. Azure Kafka business-event integration, the Reporting event-fed read model, Dispatch deployment and monitoring remain deferred until their runtime evidence is recorded.
