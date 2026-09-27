# ASSMS Prometheus & Grafana Monitoring Baseline Guide

This directory contains the Prometheus and Grafana baseline monitoring stack for the ASSMS microservice architecture.

---

## 🚀 1. Local Development Access

### Starting the Monitoring Stack
From the `assms-platform-infrastructure` repository root, launch Prometheus and Grafana using Docker Compose:

```powershell
docker-compose -f docker/docker-compose.monitoring.yml up -d
```

### Access URLs & Credentials
| Service | Local URL | Credentials | Purpose |
| --- | --- | --- | --- |
| **Grafana** | [http://localhost:3000](http://localhost:3000) | User: `admin`<br>Pass: `admin` | Dashboard visualization & metric panels |
| **Prometheus** | [http://localhost:9090](http://localhost:9090) | None | Scrape target inspection & PromQL query testing |

---

## 🔒 2. Azure Staging Access & SSH Port-Forwarding

Because staging microservices, Kafka, MySQL, and monitoring tools reside in private Azure VNets (`10.20.0.0/16` and `10.30.0.0/16`), public internet access to port 3000 and port 9090 is blocked by Network Security Groups (NSGs).

### Access via Secure SSH Port-Forwarding
Establish a temporary SSH tunnel to forward remote Grafana (3000) and Prometheus (9090) ports to your local machine:

```powershell
# Establish SSH local port forwarding tunnel
ssh -L 3000:127.0.0.1:3000 -L 9090:127.0.0.1:9090 <STAGING_VM_USER>@<STAGING_VM_IP> -i ~/.ssh/assms_deploy_ed25519
```

Once the tunnel is active, open `http://localhost:3000` or `http://localhost:9090` in your web browser.

---

## ✅ 3. Health & Verification Checklist

Follow these steps to verify target health and metric collection:

### Step A: Verify Target Status in Prometheus
1. Open [http://localhost:9090/targets](http://localhost:9090/targets).
2. Confirm that all active service jobs display **`UP`** (State `1` in green):
   - `customer-asset-service`
   - `job-service`
   - `dispatch-service`
   - `reporting-service`
   - `kafka-broker`

### Step B: Generate Test Traffic
Send test HTTP requests to the microservices:

```powershell
curl http://localhost:8080/api/health
curl http://localhost:8081/api/health
curl http://localhost:8082/api/health
curl http://localhost:8083/api/health
```

### Step C: Confirm Grafana Dashboard Panels
1. Open Grafana at [http://localhost:3000](http://localhost:3000).
2. Navigate to **Dashboards** $\rightarrow$ **ASSMS Monitoring** $\rightarrow$ **ASSMS Staging Baseline Service Monitoring**.
3. Verify that all 4 baseline panels populate with metrics:
   - **Service Availability (Health)**: Stat panel shows `UP` in green for all services.
   - **Request Rate (RPS)**: Graph displays request spikes per service.
   - **Error Rate (4xx/5xx)**: Graph tracks HTTP status error counts.
   - **Latency (p95)**: Graph displays p95 response duration in seconds.

---

## 🛠️ 4. Directory Structure Reference

```text
monitoring/
├── README.md                           <-- Operational handover guide (this file)
├── docs/
│   └── kafka-observability.md          <-- Kafka event & metric standards
├── grafana/
│   ├── dashboards/
│   │   └── baseline-dashboard.json     <-- Baseline dashboard definition
│   └── provisioning/
│       ├── dashboards/dashboards.yml   <-- Automatic dashboard provider config
│       └── datasources/prometheus.yml  <-- Automatic Prometheus datasource config
└── prometheus/
    └── config/
        └── prometheus.yml              <-- Scrape targets configuration
```
