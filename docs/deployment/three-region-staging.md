# Three-region staging deployment

The personal subscription has four regional vCPUs available in each checked region. Two backend VMs use four vCPUs together, leaving Kafka in a separate region.

| Region | Resources | VM vCPUs |
| --- | --- | --- |
| Japan East | Customer, Job, private MySQL, optional APIM | 4 |
| Central India | Dispatch, Reporting | 4 |
| East Asia | Kafka | 2 |
| Southeast Asia | Linux B1 frontend App Service | App Service quota is separate |

Set `kafka_location = "eastasia"` in the staging inputs to enable a dedicated Kafka VNet (`10.40.0.0/16`) and subnet (`10.40.2.0/24`). Kafka's NIC, NSG, optional public IP and VM all use that region. Backend clients obtain the new endpoint from the existing `kafka_bootstrap_server` output.

Kafka remains private. Both service VNets peer directly with the Kafka VNet in both directions; peering through the primary VNet alone would not work because Azure VNet peering is not transitive. Kafka does not need a MySQL DNS link because it does not access the application databases.

Set `KAFKA_PRIVATE_IP` to the new `kafka_private_ip` Terraform output when starting the staging broker. Its advertised listener must use the new private address, rather than the source environment's `10.20.2.4`. The compose file retains that old address only as a compatibility default for the existing environment. Set each backend's `Kafka__BootstrapServers` from the new `kafka_bootstrap_server` output as well.

Leaving `kafka_location` unset preserves the existing two-region layout. This setting is intended for a fresh deployment with separate state. Changing it on an existing deployment would replace region-bound Kafka resources and requires a broker-data migration plan.

Before deployment, verify both total regional quota and SKU-level restrictions for the destination subscription. On 2026-10-03 the new personal subscription blocked all checked 2-vCPU ARM sizes in Southeast Asia; the user approved Japan East as the replacement primary region. Japan East and East Asia allow `Standard_B2pls_v2`. Central India has zone restrictions for zones 1 and 2; this configuration does not select an availability zone. Each region has four total and four Bpsv2-family vCPUs available.

Complete cost estimates, database backups, runtime configuration and Terraform plan review before creating resources. Preserve the source subscription and its state until the new environment is verified and data cutover is complete.

## Deployment identity

Enable `github_oidc_enabled` to create the shared managed identity and a federated credential for each repository's `dev` branch. Set `github_oidc_subjects` from each repository's actual `sub_claim_prefix` returned by `GET /repos/ASSMS-Team/{repo}/actions/oidc/customization/sub`, appending `:ref:refs/heads/dev`. New GitHub repositories use immutable owner and repository IDs in their subject; a names-only subject will fail Azure login for those repositories. See https://docs.github.com/en/actions/reference/security/oidc.

Create or update federated credentials with Terraform `-parallelism=1`; Azure rejects concurrent writes to the same managed identity. The identity needs Network Contributor on each backend NSG and Website Contributor on the frontend web app. Runtime passwords and SSH private keys remain outside version control; GitHub stores the deployment keys and Dispatch runtime configuration as encrypted secrets.

The private MySQL server has separate database accounts for Customer, Job, Dispatch and Reporting, each restricted to its own database and required to use TLS. Backends share a fresh JWT signing key; Job and Customer share a fresh internal-service key. Internal HTTP calls use private addresses through Nginx; browser calls use certificate-validated public HTTPS endpoints.

## Verified personal-subscription migration, 3 October 2026

Japan East rejected both F1 and B1 App Service quota requests. The frontend was created in Southeast Asia on Linux B1 at USD 0.018/hour (approximately USD 13.14 for 730 hours). Its hostname is `app-assms-frontend-staging-d6a9031026.azurewebsites.net`.

The source databases were copied through private blob storage. The archive contains database SQL and table row counts, without source runtime environment files. Its SHA-256 checksum was verified before restoring all four databases. All 19 table counts matched after restoration. The old Customer VM was then deallocated and source MySQL stopped; other source VMs remained deallocated.

All four new service HTTPS health and database-health endpoints returned 200. Read-only checks using short-lived test JWTs for the migrated identities verified both technicians' assignments, assigned-job details, status history and work records, Manager reports, and browser CORS. The user also confirmed successful login on the new site. All five Kafka consumer groups were Stable with an active member.

Kafka uses a fresh broker volume. Application databases and their existing projections were retained, but source Kafka message logs and consumer offsets were not copied. The old broker disk remains available in the source environment. Do not describe this as a Kafka message-history migration.

APIM remains disabled in this deployment. Prometheus and Grafana deployment is separate Sprint 4 work. The backend API endpoints are direct HTTPS URLs.