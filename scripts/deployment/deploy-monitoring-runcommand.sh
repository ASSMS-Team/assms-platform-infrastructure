#!/usr/bin/env bash
# ==============================================================================
# ASSMS Staging Monitoring Stack Self-Contained Deployment Script (ASSMS-229)
# Can be executed via Azure Portal "Run Command" -> "RunShellScript" on Kafka VM.
# ==============================================================================
set -euo pipefail

echo "=== [1/8] Checking Docker installation ==="
if ! command -v docker >/dev/null 2>&1; then
  echo "Installing Docker..."
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
fi

echo "=== [2/8] Creating monitoring directory structure under /opt/assms/monitoring ==="
mkdir -p /opt/assms/monitoring/{config,provisioning/datasources,provisioning/dashboards,dashboards}
cd /opt/assms/monitoring

echo "=== [3/8] Writing Prometheus configuration ==="
cat << 'EOF' > /opt/assms/monitoring/config/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'customer-asset-service'
    scheme: https
    metrics_path: '/metrics'
    tls_config:
      insecure_skip_verify: true
    static_configs:
      - targets: ['20.89.44.94:443']
        labels:
          environment: 'staging'
          region: 'southeast-asia'

  - job_name: 'job-service'
    scheme: https
    metrics_path: '/metrics'
    tls_config:
      insecure_skip_verify: true
    static_configs:
      - targets: ['20.43.84.128:443']
        labels:
          environment: 'staging'
          region: 'southeast-asia'

  - job_name: 'dispatch-service'
    scheme: https
    metrics_path: '/metrics'
    tls_config:
      insecure_skip_verify: true
    static_configs:
      - targets: ['20.219.52.30:443']
        labels:
          environment: 'staging'
          region: 'central-india'

  - job_name: 'reporting-service'
    scheme: https
    metrics_path: '/metrics'
    tls_config:
      insecure_skip_verify: true
    static_configs:
      - targets: ['20.198.82.112:443']
        labels:
          environment: 'staging'
          region: 'central-india'

  - job_name: 'kafka-broker'
    static_configs:
      - targets: ['10.40.2.4:9308']
        labels:
          environment: 'staging'
          component: 'messaging'
EOF

echo "=== [4/8] Writing Grafana Datasource & Dashboard Provisioning ==="
cat << 'EOF' > /opt/assms/monitoring/provisioning/datasources/prometheus.yml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

cat << 'EOF' > /opt/assms/monitoring/provisioning/dashboards/dashboards.yml
apiVersion: 1
providers:
  - name: 'ASSMS Baseline Monitoring'
    orgId: 1
    folder: 'ASSMS Monitoring'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF

echo "=== [5/8] Writing Grafana Baseline Dashboard JSON ==="
cat << 'EOF' > /opt/assms/monitoring/dashboards/baseline-dashboard.json
{
  "annotations": {
    "list": []
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 1,
  "id": null,
  "links": [],
  "liveNow": false,
  "panels": [
    {
      "collapsed": false,
      "gridPos": {
        "h": 5,
        "w": 24,
        "x": 0,
        "y": 0
      },
      "id": 1,
      "title": "Operational Services (UP)",
      "type": "stat",
      "datasource": {
        "type": "prometheus",
        "uid": "Prometheus"
      },
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "Prometheus"
          },
          "editorMode": "code",
          "expr": "max by (job) (up == 1)",
          "legendFormat": "{{job}}",
          "range": true,
          "refId": "A"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [
            {
              "type": "value",
              "options": {
                "1": {
                  "color": "green",
                  "index": 0,
                  "text": "UP"
                }
              }
            }
          ],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              }
            ]
          },
          "unit": "short"
        },
        "overrides": []
      },
      "options": {
        "colorMode": "background",
        "graphMode": "none",
        "justifyMode": "center",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "text": {
          "titleSize": 18,
          "valueSize": 28
        },
        "textMode": "auto"
      }
    },
    {
      "collapsed": false,
      "gridPos": {
        "h": 3,
        "w": 24,
        "x": 0,
        "y": 5
      },
      "id": 9,
      "title": "Offline / Unavailable Targets (DOWN)",
      "type": "stat",
      "datasource": {
        "type": "prometheus",
        "uid": "Prometheus"
      },
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "Prometheus"
          },
          "editorMode": "code",
          "expr": "max by (job) (up == 0)",
          "legendFormat": "{{job}}",
          "range": true,
          "refId": "A"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [
            {
              "type": "value",
              "options": {
                "0": {
                  "color": "red",
                  "index": 0,
                  "text": "DOWN"
                }
              }
            }
          ],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "red",
                "value": null
              }
            ]
          },
          "unit": "short"
        },
        "overrides": []
      },
      "options": {
        "colorMode": "background",
        "graphMode": "none",
        "justifyMode": "center",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "text": {
          "titleSize": 12,
          "valueSize": 16
        },
        "textMode": "auto"
      }
    },
    {
      "collapsed": false,
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 8
      },
      "id": 2,
      "title": "Request Rate (RPS by Service)",
      "type": "timeseries",
      "datasource": {
        "type": "prometheus",
        "uid": "Prometheus"
      },
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "Prometheus"
          },
          "editorMode": "code",
          "expr": "sum(rate(http_requests_received_total[5m])) by (job)",
          "legendFormat": "{{job}}",
          "range": true,
          "refId": "A"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "custom": {
            "drawStyle": "line",
            "lineInterpolation": "smooth",
            "lineWidth": 2
          },
          "unit": "reqps"
        },
        "overrides": []
      }
    },
    {
      "collapsed": false,
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 8
      },
      "id": 3,
      "title": "HTTP Error Rate (4xx & 5xx Status Codes)",
      "type": "timeseries",
      "datasource": {
        "type": "prometheus",
        "uid": "Prometheus"
      },
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "Prometheus"
          },
          "editorMode": "code",
          "expr": "sum(rate(http_requests_received_total{code=~\"4..|5..\"}[5m])) by (job, code)",
          "legendFormat": "{{job}} - {{code}}",
          "range": true,
          "refId": "A"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "custom": {
            "drawStyle": "line",
            "lineInterpolation": "smooth",
            "lineWidth": 2
          },
          "unit": "reqps"
        },
        "overrides": []
      }
    },
    {
      "collapsed": false,
      "gridPos": {
        "h": 8,
        "w": 24,
        "x": 0,
        "y": 16
      },
      "id": 4,
      "title": "Response Time Latency (p95 percentile)",
      "type": "timeseries",
      "datasource": {
        "type": "prometheus",
        "uid": "Prometheus"
      },
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "Prometheus"
          },
          "editorMode": "code",
          "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, job))",
          "legendFormat": "{{job}} (p95)",
          "range": true,
          "refId": "A"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "custom": {
            "drawStyle": "line",
            "lineInterpolation": "smooth",
            "lineWidth": 2
          },
          "unit": "s"
        },
        "overrides": []
      }
    },
    {
      "collapsed": false,
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 24
      },
      "id": 5,
      "title": "Job Lifecycle Transitions Rate (Sprint 3)",
      "type": "timeseries",
      "datasource": {
        "type": "prometheus",
        "uid": "Prometheus"
      },
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "Prometheus"
          },
          "editorMode": "code",
          "expr": "sum by (old_status, new_status) (rate(assms_job_status_transitions_total[5m]))",
          "legendFormat": "{{old_status}} -> {{new_status}}",
          "range": true,
          "refId": "A"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "custom": {
            "drawStyle": "line",
            "lineInterpolation": "smooth",
            "lineWidth": 2
          },
          "unit": "ops"
        },
        "overrides": []
      }
    },
    {
      "collapsed": false,
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 24
      },
      "id": 6,
      "title": "Kafka JobStatusChanged Events & Consumer Health",
      "type": "timeseries",
      "datasource": {
        "type": "prometheus",
        "uid": "Prometheus"
      },
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "Prometheus"
          },
          "editorMode": "code",
          "expr": "sum by (result) (rate(assms_job_status_events_published_total[5m]))",
          "legendFormat": "Published: {{result}}",
          "range": true,
          "refId": "A"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "Prometheus"
          },
          "editorMode": "code",
          "expr": "sum by (status) (rate(assms_kafka_events_consumed_total{topic=\"job-status-changed\"}[5m]))",
          "legendFormat": "Consumed: {{status}}",
          "range": true,
          "refId": "B"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "custom": {
            "drawStyle": "line",
            "lineInterpolation": "smooth",
            "lineWidth": 2
          },
          "unit": "ops"
        },
        "overrides": []
      }
    },
    {
      "collapsed": false,
      "gridPos": {
        "h": 6,
        "w": 12,
        "x": 0,
        "y": 32
      },
      "id": 7,
      "title": "Total Completed Jobs (By Category)",
      "type": "stat",
      "datasource": {
        "type": "prometheus",
        "uid": "Prometheus"
      },
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "Prometheus"
          },
          "editorMode": "code",
          "expr": "sum by (service_category) (assms_job_completions_total)",
          "legendFormat": "{{service_category}}",
          "range": true,
          "refId": "A"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "unit": "short"
        },
        "overrides": []
      },
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "horizontal",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      }
    },
    {
      "collapsed": false,
      "gridPos": {
        "h": 6,
        "w": 12,
        "x": 12,
        "y": 32
      },
      "id": 8,
      "title": "Reporting Consumer Group Lag (job-status-changed)",
      "type": "timeseries",
      "datasource": {
        "type": "prometheus",
        "uid": "Prometheus"
      },
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "Prometheus"
          },
          "editorMode": "code",
          "expr": "sum(kafka_consumergroup_lag{consumergroup=\"assms-reporting-job-status-changed\"})",
          "legendFormat": "Consumer Lag (Unprocessed messages)",
          "range": true,
          "refId": "A"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "custom": {
            "drawStyle": "line",
            "lineInterpolation": "smooth",
            "lineWidth": 2
          },
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "yellow",
                "value": 5
              },
              {
                "color": "red",
                "value": 10
              }
            ]
          },
          "unit": "short"
        },
        "overrides": []
      }
    }
  ],
  "refresh": "10s",
  "schemaVersion": 38,
  "style": "dark",
  "tags": [
    "assms",
    "baseline",
    "staging",
    "sprint3"
  ],
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "timepicker": {
    "refresh_intervals": [
      "5s",
      "10s",
      "30s",
      "1m"
    ]
  },
  "timezone": "browser",
  "title": "ASSMS Staging Baseline Service Monitoring",
  "uid": "assms-staging-baseline",
  "version": 3
}
EOF

echo "=== [6/8] Writing Docker Compose file & credentials ==="
cat << 'EOF' > /opt/assms/monitoring/docker-compose.monitoring.staging.yml
name: assms-monitoring-staging
services:
  prometheus:
    image: prom/prometheus:v2.51.0
    container_name: assms-prometheus-staging
    restart: unless-stopped
    ports:
      - "127.0.0.1:9090:9090"
    volumes:
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_staging_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=15d'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
      - '--web.enable-lifecycle'

  grafana:
    image: grafana/grafana:10.4.0
    container_name: assms-grafana-staging
    restart: unless-stopped
    ports:
      - "127.0.0.1:3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=assmsadmin
      - GF_SECURITY_ADMIN_PASSWORD=AssmsAdmin2026!Secure
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_AUTH_ANONYMOUS_ENABLED=false
    volumes:
      - ./provisioning/datasources:/etc/grafana/provisioning/datasources:ro
      - ./provisioning/dashboards:/etc/grafana/provisioning/dashboards:ro
      - ./dashboards:/var/lib/grafana/dashboards:ro
      - grafana_staging_data:/var/lib/grafana
    depends_on:
      - prometheus

volumes:
  prometheus_staging_data:
    name: assms-prometheus-staging-data
  grafana_staging_data:
    name: assms-grafana-staging-data
EOF

echo "=== [7/8] Ensuring Docker Compose is available and starting services ==="
if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then
  echo "Installing docker-compose-plugin and docker-compose..."
  apt-get update -y && apt-get install -y docker-compose-plugin docker-compose || true
fi

COMPOSE_CMD=""
if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD="docker-compose"
fi

if [ -n "$COMPOSE_CMD" ]; then
  echo "Starting stack using: $COMPOSE_CMD"
  $COMPOSE_CMD -f /opt/assms/monitoring/docker-compose.monitoring.staging.yml up -d
else
  echo "Starting stack directly via docker run fallback..."
  docker volume create assms-prometheus-staging-data || true
  docker volume create assms-grafana-staging-data || true
  docker rm -f assms-prometheus-staging 2>/dev/null || true
  docker run -d \
    --name assms-prometheus-staging \
    --restart unless-stopped \
    -p 127.0.0.1:9090:9090 \
    -v /opt/assms/monitoring/config/prometheus.yml:/etc/prometheus/prometheus.yml:ro \
    -v assms-prometheus-staging-data:/prometheus \
    prom/prometheus:v2.51.0 \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/prometheus \
    --storage.tsdb.retention.time=15d \
    --web.console.libraries=/usr/share/prometheus/console_libraries \
    --web.console.templates=/usr/share/prometheus/consoles \
    --web.enable-lifecycle

  docker rm -f assms-grafana-staging 2>/dev/null || true
  docker run -d \
    --name assms-grafana-staging \
    --restart unless-stopped \
    -p 127.0.0.1:3000:3000 \
    -e GF_SECURITY_ADMIN_USER=assmsadmin \
    -e GF_SECURITY_ADMIN_PASSWORD=AssmsAdmin2026!Secure \
    -e GF_USERS_ALLOW_SIGN_UP=false \
    -e GF_AUTH_ANONYMOUS_ENABLED=false \
    -v /opt/assms/monitoring/provisioning/datasources:/etc/grafana/provisioning/datasources:ro \
    -v /opt/assms/monitoring/provisioning/dashboards:/etc/grafana/provisioning/dashboards:ro \
    -v /opt/assms/monitoring/dashboards:/var/lib/grafana/dashboards:ro \
    -v assms-grafana-staging-data:/var/lib/grafana \
    grafana/grafana:10.4.0
fi

echo "=== [8/8] Installing and enabling systemd service ==="
if [ "$COMPOSE_CMD" = "docker compose" ]; then
  cat << 'EOF' > /etc/systemd/system/assms-monitoring.service
[Unit]
Description=ASSMS Staging Prometheus and Grafana Monitoring Stack
After=docker.service network-online.target
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/assms/monitoring
ExecStart=/usr/bin/docker compose -f /opt/assms/monitoring/docker-compose.monitoring.staging.yml up -d
ExecStop=/usr/bin/docker compose -f /opt/assms/monitoring/docker-compose.monitoring.staging.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable assms-monitoring.service
elif [ "$COMPOSE_CMD" = "docker-compose" ]; then
  cat << 'EOF' > /etc/systemd/system/assms-monitoring.service
[Unit]
Description=ASSMS Staging Prometheus and Grafana Monitoring Stack
After=docker.service network-online.target
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/assms/monitoring
ExecStart=/usr/bin/docker-compose -f /opt/assms/monitoring/docker-compose.monitoring.staging.yml up -d
ExecStop=/usr/bin/docker-compose -f /opt/assms/monitoring/docker-compose.monitoring.staging.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable assms-monitoring.service
fi

echo ""
echo "=============================================================================="
echo "DEPLOYMENT SUCCESSFUL!"
docker ps --filter "name=assms-"
echo "=============================================================================="

