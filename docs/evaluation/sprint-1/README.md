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

Use each repository's remote `main` branch for the Sprint 1 evaluation. The Sprint 1 work from Dispatch, Platform Infrastructure and Reporting was promoted from `dev` to `main` on 7 September 2026. Customer & Asset, Frontend and Job were already available on `main`.

## GitHub Actions evidence

The following authenticated GitHub screenshots were captured on 7 September 2026. Each screenshot records the successful workflow conclusion and its completed jobs. The service screenshots also show uploaded test-result artifacts where the workflow produces one.

| Repository | Verified workflow run | Screenshot | Result |
|---|---|---|---|
| Customer & Asset | [`Customer Asset Service CI` run 33413844336](https://github.com/ASSMS-Team/assms-customer-asset-service/actions/runs/33413844336) | [customer-asset-ci.png](github-actions/customer-asset-ci.png) | Successful; Terraform and .NET build/test jobs; `customer-asset-test-results` artifact |
| Dispatch | [`Dispatch Service CI` run 34138037868](https://github.com/ASSMS-Team/assms-dispatch-service/actions/runs/34138037868) | [dispatch-ci.png](github-actions/dispatch-ci.png) | Successful; Terraform and .NET build/test jobs; `dispatch-service-test-results` artifact |
| Frontend | [`Frontend CI` run 34137926990](https://github.com/ASSMS-Team/assms-frontend/actions/runs/34137926990) | [frontend-ci.png](github-actions/frontend-ci.png) | Successful; Terraform, lint and production-build jobs; no test artifact is defined by this workflow |
| Job | [`Job Service CI` run 33413962457](https://github.com/ASSMS-Team/assms-job-service/actions/runs/33413962457) | [job-service-ci.png](github-actions/job-service-ci.png) | Successful; Terraform and .NET build/test jobs; `job-service-test-results` artifact |
| Platform Infrastructure | [`Terraform CI` run 34137843157](https://github.com/ASSMS-Team/assms-platform-infrastructure/actions/runs/34137843157) | [platform-terraform-ci.png](github-actions/platform-terraform-ci.png) | Successful Terraform validation; this workflow does not define a test artifact |
| Reporting | [`Reporting Service CI` run 34138128606](https://github.com/ASSMS-Team/assms-reporting-service/actions/runs/34138128606) | [reporting-service-ci.png](github-actions/reporting-service-ci.png) | Successful; Terraform and .NET build/test jobs; `reporting-service-test-results` artifact |

These records verify CI only. A CD workflow is described as implemented unless a separate successful deployment run and runtime check are recorded.

## Repository verification recorded on 7 September 2026

- All six remote `main` branches contain their expected CI workflows.
- Terraform formatting passed.
- All 13 Terraform roots validated successfully: bootstrap, staging and production roots across the six repositories.
- Frontend lint and production build passed.
- Local .NET execution was unavailable because the workstation had .NET SDK 10 while the repositories pin SDK 8.0.424. The corresponding GitHub Actions runs are the required test evidence.
- No credentials or private keys are included in this evidence folder.

## Honest Sprint 1 boundary

The project provides a production-oriented foundation and recorded staging deployment evidence. It does not claim that production is deployed. Azure Kafka business-event integration, the Reporting event-fed read model, Dispatch deployment and monitoring remain deferred until their runtime evidence is recorded.
