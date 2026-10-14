# ASSMS Staging Monitoring Deployment & Operations Guide (ASSMS-229)

## 📌 1. Purpose & Overview

This document defines the deployment, network architecture, resource considerations, security controls, and operational procedures for running the **Prometheus** and **Grafana** monitoring stack in the ASSMS Azure Staging Environment for Sprint 4.

The setup reuses existing Prometheus scrape configurations, Grafana dashboards, and application metrics implemented locally, adapting them to the live Azure staging infrastructure while preserving strict cost consciousness, access control, and persistence guarantees.

This task supports **ASSMS-60 (TASK-44 Finalize Monitoring and Observability Dashboard)**.

---

## 💰 2. Cost-Conscious Azure Hosting Location & Sizing

### 2.1 Capacity Check & Host Selection

The ASSMS staging infrastructure is deployed in the Azure `southeastasia` region under resource group `rg-assms-staging`. The platform subnet (`snet-assms-platform-staging`, `10.20.2.0/24`) hosts platform-level services:

| Host / VM | Sizing / SKU | Private IP | Existing Services | Available Capacity |
| :--- | :--- | :--- | :--- | :--- |
| **`vm-assms-kafka-staging`** | `Standard_B2pls_v2` (2 vCPU, 4 GiB RAM, ARM64) | `10.20.2.4` | Kafka Broker (`9092`), Topic-Init | **~1.5 vCPU, ~2.5 GiB RAM idle** |

#### Cost Decision Matrix:
* **Option A (Colocation on `vm-assms-kafka-staging`) — Selected & Recommended**:
  - Running Prometheus and Grafana via Docker Compose directly on `vm-assms-kafka-staging`.
  - **Incremental VM Cost: $0.00 / month**.
  - **Memory Footprint**: Prometheus TSDB (~350–500 MiB), Grafana (~120–180 MiB). Combined utilization remains under 50% of the host's 4 GiB RAM.
  - **Local Latency**: Co-located with the Kafka broker and Kafka exporter (`10.20.2.4:9308`), reducing network hops.
* **Option B (Dedicated `Standard_B1ms` or `Standard_B2s` VM)**:
  - Additional infrastructure cost: ~$15.00–$30.00 / month. Unnecessary for Sprint 4 evaluation and staging workloads.

### 2.2 Storage & Retention Policy

* **Prometheus Data Retention**: `--storage.tsdb.retention.time=15d` to guarantee bounded disk usage (< 5 GiB) on the OS disk.
* **Storage Volumes**:
  - `prometheus_staging_data` (Named Docker Volume) mounted to `/prometheus`
  - `grafana_staging_data` (Named Docker Volume) mounted to `/var/lib/grafana`
* **Restart Policy**: `restart: unless-stopped` on both containers + a dedicated `systemd` unit (`assms-monitoring.service`) to survive host reboots.

---

## 🔒 3. Security, Network Architecture & Access Controls

### 3.1 Network Isolation

Prometheus (port `9090`) and Grafana (port `3000`) must **never be directly exposed to the public internet**.

```text
               +-------------------------------------------------------------+
               |                  Private Azure VNet (10.20.0.0/16)          |
               |                                                             |
               |   +-----------------------+     +-----------------------+   |
               |   | Services Subnet       |     | Platform Subnet       |   |
               |   | (10.20.1.0/24)        |     | (10.20.2.0/24)        |   |
               |   |                       |     |                       |   |
               |   | Customer-Asset (443)  |     | vm-assms-kafka-staging|   |
               |   | Job Service (443)     |<----+ (10.20.2.4)           |   |
               |   | Dispatch Service (443)|     |  - Prometheus (9090)  |   |
               |   | Reporting Svc (443)   |     |  - Grafana (3000)     |   |
               |   +-----------------------+     +-----------------------+   |
               +---------------------------------------------^---------------+
                                                             |
                                            SSH Port Tunnel (22 -> 3000, 9090)
                                                             |
                                               +-------------+-------------+
                                               | Authorized Engineer Admin |
                                               | (Local Browser: 3000/9090)|
                                               +---------------------------+
```

* Containers bind exclusively to `127.0.0.1:9090` and `127.0.0.1:3000` on the VM host.
* NSGs block all public inbound traffic on ports `9090` and `3000`.

### 3.2 Secure Administrator Access via SSH Port-Forwarding

Authorized team members access Grafana and Prometheus using local SSH port-forwarding over the approved bastion/deploy key:

```powershell
# Open tunnel to Grafana (3000) and Prometheus (9090)
ssh -N -L 3000:127.0.0.1:3000 -L 9090:127.0.0.1:9090 assmsadmin@<STAGING_VM_PUBLIC_IP_OR_BASTION> -i ~/.ssh/assms_deploy_ed25519
```

Once connected:
- **Grafana**: [http://localhost:3000](http://localhost:3000)
- **Prometheus Targets**: [http://localhost:9090/targets](http://localhost:9090/targets)

### 3.3 Credentials & Authentication

* Grafana enforces mandatory authentication (`GF_AUTH_ANONYMOUS_ENABLED=false`).
* User sign-up is disabled (`GF_USERS_ALLOW_SIGN_UP=false`).
* Credentials are provided via `.env.monitoring.staging` on the host, with filesystem permissions `600`.
* **Zero Secrets Committed**: Only `.env.monitoring.staging.example` is committed to git.

---

## 🚀 4. Deployment Procedure

### 4.1 Automated Deployment Script

Run the automated deployment script from the repository root:

```bash
bash scripts/deployment/deploy-monitoring-staging.sh
```

### 4.2 Manual Step-by-Step Procedure

1. **Copy Deployment & Configuration Files to VM**:
   ```bash
   sudo mkdir -p /opt/assms/monitoring/{config,provisioning/datasources,provisioning/dashboards,dashboards}
   
   sudo cp docker/docker-compose.monitoring.staging.yml /opt/assms/monitoring/docker-compose.monitoring.staging.yml
   sudo cp monitoring/prometheus/config/prometheus.staging.yml /opt/assms/monitoring/config/prometheus.yml
   sudo cp monitoring/grafana/provisioning/datasources/* /opt/assms/monitoring/provisioning/datasources/
   sudo cp monitoring/grafana/provisioning/dashboards/* /opt/assms/monitoring/provisioning/dashboards/
   sudo cp monitoring/grafana/dashboards/* /opt/assms/monitoring/dashboards/
   ```

2. **Configure Host Environment File**:
   ```bash
   sudo cp .env.monitoring.staging.example /opt/assms/monitoring/.env.monitoring.staging
   sudo chmod 600 /opt/assms/monitoring/.env.monitoring.staging
   
   # Edit with secure admin password:
   sudo nano /opt/assms/monitoring/.env.monitoring.staging
   ```

3. **Deploy with Docker Compose**:
   ```bash
   cd /opt/assms/monitoring
   sudo docker compose --env-file .env.monitoring.staging -f docker-compose.monitoring.staging.yml up -d
   ```

4. **Install Systemd Auto-Recovery Unit**:
   ```bash
   sudo cp monitoring/systemd/assms-monitoring.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable assms-monitoring.service
   ```

---

## ✅ 5. Verification Checklist & Scrape Targets

### 5.1 Scrape Targets Health

Access [http://localhost:9090/targets](http://localhost:9090/targets) through the SSH tunnel and confirm the following endpoints report **`UP`**:

| Job Name | Target URL | Scheme | Expected Status | Description |
| :--- | :--- | :--- | :--- | :--- |
| `prometheus` | `localhost:9090` | HTTP | `UP` | Internal Prometheus health |
| `customer-asset-service` | `20.212.211.206:443/metrics` | HTTPS | `UP` | Customer & Asset microservice (SEA) |
| `job-service` | `52.139.199.11:443/metrics` | HTTPS | `UP` | Job microservice (SEA) |
| `dispatch-service` | `20.204.99.8:443/metrics` | HTTPS | `UP` | Dispatch microservice (Central India) |
| `reporting-service` | `4.213.126.53:443/metrics` | HTTPS | `UP` | Reporting microservice (Central India) |
| `apim-gateway` | `apim-assms-staging-45ff260826.azure-api.net:443` | HTTPS | `UP` | Staging API Gateway metrics |
| `kafka-broker` | `10.20.2.4:9308` | HTTP | `UP` (or documented follow-up) | JMX / Kafka exporter broker lag |

### 5.2 Grafana Dashboard Panels Verification

Navigate to **Dashboards $\rightarrow$ ASSMS Monitoring $\rightarrow$ ASSMS Staging Baseline Service Monitoring**:

1. **Operational Services (UP)**: Stat panel showing green `UP` boxes for active backend services.
2. **Offline / Unavailable Targets (DOWN)**: Shows `0` or flags disconnected endpoints.
3. **Request Rate (RPS by Service)**: Timeseries graph of incoming HTTP traffic.
4. **HTTP Error Rate (4xx & 5xx)**: Tracks any HTTP client/server errors.
5. **Response Time Latency (p95 percentile)**: P95 duration across microservices.
6. **Job Lifecycle Transitions Rate (Sprint 3)**: Reflects `assms_job_status_transitions_total` (`ASSIGNED -> IN_PROGRESS`, `IN_PROGRESS -> COMPLETED`).
7. **Kafka JobStatusChanged Events & Consumer Health**: Compares published vs consumed events.
8. **Total Completed Jobs (By Category)**: Breakdown by repair / maintenance categories.
9. **Reporting Consumer Group Lag**: Displays queue lag for `assms-reporting-job-status-changed`.

*Note on Missing Exporters*: If the Kafka broker does not have `kafka-exporter` running on port `9308`, panel 8 (`Consumer Group Lag`) and target `kafka-broker` will report DOWN. This does not block backend service monitoring; follow-up action is to deploy `danielqsj/kafka-exporter:latest` on the Kafka Compose stack.

---

## 🔄 6. Maintenance, Backup & Recovery Runbook

### 6.1 Host & Service Restart Verification

To verify resilience against service or host crashes:

```bash
# 1. Simulate service restart
sudo systemctl restart assms-monitoring.service

# 2. Check running containers
sudo docker compose -f /opt/assms/monitoring/docker-compose.monitoring.staging.yml ps

# 3. Verify data persistence
# Log in to Grafana (http://localhost:3000) and verify historical TSDB metrics and dashboard state persist.
```

### 6.2 TSDB Snapshot & Backup

Prometheus supports online snapshots:

```bash
# Trigger clean snapshot via lifecycle API
curl -XPOST http://localhost:9090/api/v1/admin/tsdb/snapshot

# Archive Prometheus and Grafana volumes
sudo tar -czvf /opt/assms/backups/monitoring-$(date +%Y%m%d%H%M%S).tar.gz \
  /var/lib/docker/volumes/assms-prometheus-staging-data \
  /var/lib/docker/volumes/assms-grafana-staging-data
```

### 6.3 Rollback Procedure

If a configuration change breaks Prometheus or Grafana:

1. Stop current containers:
   ```bash
   sudo docker compose -f /opt/assms/monitoring/docker-compose.monitoring.staging.yml down
   ```
2. Revert configuration files from git:
   ```bash
   git checkout <PREVIOUS_STABLE_COMMIT> -- monitoring/ docker/
   sudo cp monitoring/prometheus/config/prometheus.staging.yml /opt/assms/monitoring/config/prometheus.yml
   sudo cp monitoring/grafana/dashboards/* /opt/assms/monitoring/dashboards/
   ```
3. Restart monitoring stack:
   ```bash
   sudo docker compose --env-file /opt/assms/monitoring/.env.monitoring.staging \
     -f /opt/assms/monitoring/docker-compose.monitoring.staging.yml up -d
   ```

### 6.4 Shutdown and Startup

```bash
# Graceful Shutdown
sudo systemctl stop assms-monitoring.service

# Startup
sudo systemctl start assms-monitoring.service
```
