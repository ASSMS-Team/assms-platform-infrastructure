# Sprint 3 Azure Deployment and Validation Guide

## 1. Purpose & Scope

This document defines the deployment, verification, and smoke-testing procedures for the **Sprint 3** increment in Azure staging environment.

The Sprint 3 increment delivers:
- **Technician Field-Work Lifecycle**: Starting jobs, logging service work records, and completing jobs in [Job Service](../../../assms-job-service).
- **Asynchronous Status Event Integration**: `JobStatusChanged` event publishing over Kafka topic `job-status-changed` with automatic projection in [Reporting Service](../../../assms-reporting-service).
- **Consolidated API Gateway Access**: Unified routing through Azure API Management (APIM) gateway for frontend interactions.
- **Enhanced Observability**: Prometheus instrumentation and Grafana dashboards for lifecycle transitions and Kafka consumer group health.

---

## 2. Architecture & Service Topology

```text
                               +-----------------------------+
                               |     React Web Frontend      |
                               +--------------+--------------+
                                              |
                                              v
                              +---------------+---------------+
                              |     Azure API Management      |
                              |           Gateway             |
                              +---------------+---------------+
                                              |
         +--------------------+---------------+--------------------+
         | (/jobs/api)        | (/dispatch/api) | (/reports/api)   | (/customer/api)
         v                    v                 v                  v
+-----------------+  +-----------------+  +-----------------+  +-----------------+
|   Job Service   |  | Dispatch Service|  |Reporting Service|  | Customer Service|
|     (ARM64)     |  |     (ARM64)     |  |     (ARM64)     |  |     (ARM64)     |
+--------+--------+  +--------+--------+  +--------+--------+  +--------+--------+
         |                    |                    |                    |
         | (publishes)        | (publishes)        | (consumes)         |
         v                    v                    v                    |
+-----------------------------------------------------------------------+--------+
|                               Kafka Cluster                                    |
|   Topics: job-status-changed, job-assignments                                 |
+--------------------------------------------------------------------------------+
         |                    |                    |                    |
         v                    v                    v                    v
+-----------------+  +-----------------+  +-----------------+  +-----------------+
|   Job MySQL DB  |  | Dispatch MySQL  |  | Reporting MySQL |  | Customer MySQL  |
+-----------------+  +-----------------+  +-----------------+  +-----------------+
```

---

## 3. Step-by-Step Deployment Execution

### Step 1: CI Build & Test Gate
- All pull requests and pushes to `dev` trigger GitHub Actions CI workflows.
- CI verifies .NET compilation, xUnit test coverage, and Terraform formatting/validation.
- Merges to `dev` automatically trigger downstream staging CD pipelines.

### Step 2: Database Migrations (Safe Application)
Job Service database schema changes for Sprint 3 are applied via numbered migration scripts:
- `V01__create_jobs.sql`: Core jobs schema.
- `V02__add_job_assignment.sql`: Job assignment details.
- `V03__add_job_started_at.sql`: Adds `started_at` column and indices.
- `V04__create_service_work_records.sql`: Adds `service_work_records` table.
- `V05__create_job_status_history.sql`: Adds `job_status_history` audit table.
- `V06__add_job_completed_at.sql`: Adds `completed_at` column and performance index.

**Execution Mechanism**:
During container deployment, the container runs `--apply-migrations` using `JobMigrationRunner` prior to accepting live requests.

### Step 3: Container Deployment to Azure Staging
Each service CD pipeline (`staging-cd.yml`) performs:
1. Builds exact Linux ARM64 image tagged with `${DEPLOY_SHA}`.
2. Creates a temporary NSG inbound rule whitelisting the GitHub runner IP on port 22.
3. Transports image to Azure VM via SCP.
4. Executes container migration runner:
   ```bash
   sudo docker run --rm --env-file /etc/assms/job.env assms-job-service:${DEPLOY_SHA} --apply-migrations
   ```
5. Launches service container with system restart policies:
   ```bash
   sudo docker run -d --name assms-job-service --restart unless-stopped \
     --env-file /etc/assms/job.env -p 127.0.0.1:8080:8080 assms-job-service:${DEPLOY_SHA}
   ```
6. Runs health probes against `/api/health` and `/api/health/db`.
7. Tears down temporary NSG inbound rule.

---

## 4. Environment & Kafka Configuration Checklist

| Environment Setting | Expected Value / Configuration |
| :--- | :--- |
| **MySQL Connection String** | `Server=...;Database=jobdb;User=job_svc;Password=...;SslMode=Preferred;` |
| **Kafka Bootstrap Servers** | `10.0.2.10:9092` (or staging Kafka VM IP) |
| **Topic: Job Status Changed** | `job-status-changed` (Partitions: 3, ReplicationFactor: 1) |
| **Consumer Group** | `reporting-job-status-changed` |
| **APIM Gateway Base URL** | `https://apim-assms-staging.azure-api.net` |

---

## 5. Automated Health & Smoke Testing

### Running Post-Deployment Health Probes:
```powershell
.\scripts\validation\validate-azure-deployments.ps1 `
  -ApimGatewayUrl "https://apim-assms-staging.azure-api.net"
```

### Running End-to-End Technician Smoke Test:
```powershell
.\scripts\validation\smoke-test-sprint3.ps1 `
  -BaseUrl "https://apim-assms-staging.azure-api.net" `
  -AuthToken "<BEARER_JWT_TOKEN>"
```

The smoke test verifies the full lifecycle:
1. `PUT /api/jobs/{id}/start` -> Status transitions to `IN_PROGRESS`.
2. `POST /api/jobs/{id}/work-records` -> Service work record saved with parts/hours.
3. `PUT /api/jobs/{id}/complete` -> Status transitions to `COMPLETED`.
4. Kafka publishes `JobStatusChanged` event.
5. Reporting Service consumes event and updates completion projections.

---

## 6. Success Criteria
- [x] All 4 microservices respond HTTP 200 on `/api/health` and `/api/health/db`.
- [x] APIM gateway forwards traffic without altering JWT authorization boundaries.
- [x] Database schema is upgraded cleanly with no data loss.
- [x] Kafka consumer group `reporting-job-status-changed` displays zero lag under normal load.
- [x] Prometheus metrics and Grafana dashboards render lifecycle counters and completion rates.
