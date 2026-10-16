#!/usr/bin/env bash
# ==============================================================================
# ASSMS Staging Monitoring Stack Deployment Script (ASSMS-229)
# Deploys Prometheus and Grafana on the Azure staging environment.
# ==============================================================================

set -euo pipefail

TARGET_DIR="/opt/assms/monitoring"
CONFIG_DIR="${TARGET_DIR}/config"
PROVISIONING_DIR="${TARGET_DIR}/provisioning"
DASHBOARDS_DIR="${TARGET_DIR}/dashboards"
ENV_FILE="${TARGET_DIR}/.env.monitoring.staging"

echo "=== [1/6] Verifying prerequisites on host ==="
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is not installed"; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "ERROR: docker compose is not installed"; exit 1; }

echo "=== [2/6] Preparing directory structure under ${TARGET_DIR} ==="
sudo mkdir -p "${CONFIG_DIR}" "${PROVISIONING_DIR}/datasources" "${PROVISIONING_DIR}/dashboards" "${DASHBOARDS_DIR}"

echo "=== [3/6] Syncing configuration & dashboard provisioning ==="
# Determine source directory (relative to script or current directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

sudo cp "${REPO_ROOT}/docker/docker-compose.monitoring.staging.yml" "${TARGET_DIR}/docker-compose.monitoring.staging.yml"
sudo cp "${REPO_ROOT}/monitoring/prometheus/config/prometheus.staging.yml" "${CONFIG_DIR}/prometheus.yml"
sudo cp -r "${REPO_ROOT}/monitoring/grafana/provisioning/datasources/"* "${PROVISIONING_DIR}/datasources/"
sudo cp -r "${REPO_ROOT}/monitoring/grafana/provisioning/dashboards/"* "${PROVISIONING_DIR}/dashboards/"
sudo cp -r "${REPO_ROOT}/monitoring/grafana/dashboards/"* "${DASHBOARDS_DIR}/"

echo "=== [4/6] Verifying environment file ==="
if [ ! -f "${ENV_FILE}" ]; then
  echo "WARNING: ${ENV_FILE} not found. Creating from example template..."
  sudo cp "${REPO_ROOT}/.env.monitoring.staging.example" "${ENV_FILE}"
  echo "IMPORTANT: Generated initial ${ENV_FILE}. Update GF_SECURITY_ADMIN_PASSWORD before production/evaluation use."
fi
sudo chmod 600 "${ENV_FILE}"

echo "=== [5/6] Deploying Docker Compose monitoring stack ==="
cd "${TARGET_DIR}"
sudo docker compose --env-file "${ENV_FILE}" -f docker-compose.monitoring.staging.yml up -d

echo "=== [6/6] Checking container health ==="
sleep 5
sudo docker compose -f docker-compose.monitoring.staging.yml ps

echo ""
echo "=============================================================================="
echo "SUCCESS: ASSMS Staging Monitoring stack deployed successfully."
echo "Prometheus: http://127.0.0.1:9090 (Internal)"
echo "Grafana:    http://127.0.0.1:3000 (Internal)"
echo ""
echo "To access securely from an administrator workstation via SSH port-forwarding:"
echo "ssh -L 3000:127.0.0.1:3000 -L 9090:127.0.0.1:9090 assmsadmin@<STAGING_VM_IP> -i ~/.ssh/assms_deploy_ed25519"
echo "=============================================================================="
