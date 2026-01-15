# Monitoring System - Complete Guide

This document provides a comprehensive guide to the monitoring infrastructure for the task-manager application.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Components](#components)
4. [Accessing the Monitoring Stack](#accessing-the-monitoring-stack)
5. [Metrics](#metrics)
6. [Logs](#logs)
7. [Alerts](#alerts)
8. [Request Tracing](#request-tracing)
9. [Troubleshooting](#troubleshooting)

---

## Overview

The monitoring system provides comprehensive observability for the task-manager application through:

- **Metrics Collection**: Prometheus scraping application and Go runtime metrics
- **Visualization**: Grafana dashboards for real-time monitoring
- **Alerting**: 8 configured alerts covering resource and application issues
- **Logging**: Structured JSON logs with correlation ID tracking
- **Tracing**: Request tracing using correlation IDs

### Requirements Satisfied

✅ **Collect Metrics** - HTTP requests, latency, Go runtime stats
✅ **Collect Traces** - Correlation ID-based request tracing
✅ **Collect Logs** - Structured JSON logging with correlation_id
✅ **Resource Alerts** - CPU, memory, latency, pod restarts
✅ **Application Alerts** - Error rates, traffic, concurrency
✅ **Request Tracing** - End-to-end tracing via correlation_id

---

## Architecture

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ HTTP Request
       ▼
┌──────────────────────────────────────────┐
│  Task Manager (Go App)                   │
│  ┌────────────────────────────────────┐  │
│  │ 1. Correlation ID Middleware       │  │ ← Generates UUID
│  │    • Generates unique ID           │  │
│  │    • Sets response header          │  │
│  └──────────┬─────────────────────────┘  │
│             ▼                             │
│  ┌────────────────────────────────────┐  │
│  │ 2. Structured Logger               │  │ ← Logs with correlation_id
│  │    • Creates logger with ID        │  │
│  │    • Logs request start/complete   │  │
│  └──────────┬─────────────────────────┘  │
│             ▼                             │
│  ┌────────────────────────────────────┐  │
│  │ 3. Prometheus Middleware           │  │ ← Collects metrics
│  │    • Increments request counter    │  │
│  │    • Records latency histogram     │  │
│  └──────────┬─────────────────────────┘  │
│             ▼                             │
│  ┌────────────────────────────────────┐  │
│  │ 4. Business Logic                  │  │
│  └────────────────────────────────────┘  │
└──────────────┬───────────────────────────┘
               │
       ┌───────┴───────┬──────────────┬──────────────┐
       ▼               ▼              ▼              ▼
┌─────────────┐ ┌──────────────┐ ┌─────────┐ ┌──────────────┐
│ Prometheus  │ │ Cloud        │ │ Response│ │ /metrics     │
│ (Scrapes)   │ │ Logging      │ │ Header  │ │ Endpoint     │
└──────┬──────┘ └──────────────┘ └─────────┘ └──────────────┘
       │
       ├─────► Evaluates Alert Rules every 30s
       │
       ▼
┌─────────────────┐      ┌──────────────┐
│ AlertManager    │────► │ Notifications│
│ (Routes Alerts) │      │ (Future)     │
└─────────────────┘      └──────────────┘
       │
       ▼
┌─────────────────┐
│ Grafana         │
│ (Visualizations)│
└─────────────────┘
```

---

## Components

### 1. Prometheus

**Purpose**: Metrics collection and alert evaluation

**What it does**:
- Scrapes `/metrics` endpoint from task-manager every 30 seconds
- Stores time-series metric data
- Evaluates alert rules every 30 seconds
- Sends firing alerts to AlertManager

**Access**:
- Via port-forward: `kubectl port-forward -n monitoring deployment/prometheus 9090:9090`
- Then visit: http://localhost:9090

### 2. Grafana

**Purpose**: Metrics visualization and dashboards

**Access**:
- URL: http://34.54.54.224
- Username: `admin`
- Password: `changeme123`

**Dashboard**: Navigate to **Dashboards → Browse → Task Manager - Overview**

**Panels**:
- HTTP Request Rate (by method and path)
- HTTP Request Latency (p95, p99)
- CPU Usage (%)
- Memory Usage (allocated vs system)
- Goroutines count
- GC Pause Duration

### 3. AlertManager

**Purpose**: Alert routing and management

**What it does**:
- Receives alerts from Prometheus
- Groups and routes alerts
- Manages silences and inhibitions
- Future: Send notifications (email, Slack, PagerDuty)

**Access**:
- URL: http://34.160.89.136
- View active alerts, silences, and alert history

### 4. Cloud Logging

**Purpose**: Centralized log aggregation

**What it does**:
- Automatically collects pod logs from GKE
- Indexes structured JSON logs
- Provides search and filtering capabilities

**Access**:
- Web UI: https://console.cloud.google.com/logs/query?project=iaasepitech

**Common queries**:
```
# All task-manager logs
resource.labels.cluster_name="team5-gke-cluster"
resource.labels.namespace_name="default"

# By correlation_id
jsonPayload.correlation_id="<your-correlation-id>"

# Request logs only
jsonPayload.msg=~"request (started|completed)"

# Errors only
severity="ERROR"
```

---

## Metrics

### Application Metrics

**HTTP Metrics** (from `app/internal/httpapi/middleware/prometheus.go`):

```
http_requests_total{method="GET", path="/tasks", status="200"}
http_request_duration_seconds_bucket{method="GET", path="/tasks", le="0.1"}
http_requests_in_flight{method="GET", path="/tasks"}
```

**Go Runtime Metrics** (automatically exported):

```
go_memstats_alloc_bytes          # Current heap allocation
go_memstats_sys_bytes            # Total memory from OS
go_goroutines                    # Active goroutines
go_gc_duration_seconds           # GC pause duration
process_cpu_seconds_total        # CPU time consumed
process_resident_memory_bytes    # RSS memory
```

### Viewing Metrics

**Via Prometheus**:
```bash
kubectl port-forward -n monitoring deployment/prometheus 9090:9090
# Visit: http://localhost:9090/graph
```

**Via Grafana**:
- Go to Explore tab
- Select Prometheus datasource
- Write PromQL queries

**Via Application Endpoint**:
```bash
kubectl port-forward deployment/task-manager 8080:8080
curl http://localhost:8080/metrics
```

### Example PromQL Queries

```promql
# Request rate per second
rate(http_requests_total{job="task-manager"}[5m])

# Error rate percentage
(sum(rate(http_requests_total{job="task-manager",status=~"5.."}[5m]))
/ sum(rate(http_requests_total{job="task-manager"}[5m]))) * 100

# p95 latency
histogram_quantile(0.95,
  rate(http_request_duration_seconds_bucket{job="task-manager"}[5m])
)

# Memory usage in MB
go_memstats_alloc_bytes{job="task-manager"} / 1024 / 1024

# CPU usage percentage
rate(process_cpu_seconds_total{job="task-manager"}[5m]) * 100
```

---

## Logs

### Log Format

All logs are structured JSON with the following fields:

```json
{
  "time": "2026-01-15T10:30:45.123Z",
  "level": "INFO",
  "msg": "request completed",
  "correlation_id": "a3b2c1d4e5f6g7h8i9j0k1l2m3n4o5p6",
  "method": "POST",
  "path": "/tasks",
  "status": 201,
  "duration_ms": 45,
  "remote_addr": "10.4.0.1"
}
```

### Log Levels

- **INFO**: Normal operations (request start/complete)
- **WARN**: Warning conditions
- **ERROR**: Error conditions
- **DEBUG**: Detailed debugging (if enabled)

### Viewing Logs

**Via kubectl**:
```bash
# Tail logs from all task-manager pods
kubectl logs -l app.kubernetes.io/name=task-manager --tail=100 -f

# Get logs from specific pod
kubectl logs <pod-name> -f

# Filter by timestamp
kubectl logs -l app.kubernetes.io/name=task-manager --since=1h
```

**Via Cloud Logging**:

1. Go to: https://console.cloud.google.com/logs/query?project=iaasepitech
2. Use query builder or advanced filter

**Common Cloud Logging Queries**:
```
# All task-manager logs
resource.type="k8s_container"
resource.labels.cluster_name="team5-gke-cluster"
resource.labels.namespace_name="default"
resource.labels.container_name="task-manager"

# By correlation_id
jsonPayload.correlation_id="abc123def456"

# By status code
jsonPayload.status=500

# By path
jsonPayload.path="/tasks"

# Errors only
severity="ERROR"

# Slow requests (>1 second)
jsonPayload.duration_ms>1000
```

### Log Implementation

Logs are generated by the correlation middleware in `app/internal/httpapi/middleware/correlation.go`:

1. **Request Start**: Logged when request enters middleware
2. **Request Complete**: Logged after response is sent
3. **Correlation ID**: Unique ID attached to all logs for that request

The structured logger is implemented in `app/internal/logger/logger.go` using Go's `log/slog` package.

---

## Alerts

### Alert Configuration

All alerts are defined in `helm/prometheus-alerts/alert-rules.yaml`.

### Resource Alerts

| Alert Name | Condition | Duration | Severity |
|------------|-----------|----------|----------|
| **HighCPUUsage** | CPU > 80% | 2 minutes | warning |
| **HighMemoryUsage** | Memory > 400MB | 2 minutes | warning |
| **HighRequestLatency** | p95 latency > 1s | 2 minutes | warning |
| **PodRestarting** | Pod restart detected | 1 minute | critical |

### Application Alerts

| Alert Name | Condition | Duration | Severity |
|------------|-----------|----------|----------|
| **HighServerErrorRate** | 5xx rate > 5% | 2 minutes | critical |
| **HighClientErrorRate** | 4xx rate > 20% | 5 minutes | warning |
| **NoRequests** | No traffic | 3 minutes | critical |
| **HighRequestsInFlight** | > 50 concurrent requests | 2 minutes | warning |

### Alert States

1. **Inactive**: Condition not met
2. **Pending**: Condition met, waiting for duration
3. **Firing**: Condition met for full duration, sent to AlertManager
4. **Resolved**: Condition no longer met

### Viewing Alerts

**Prometheus UI**:
```bash
kubectl port-forward -n monitoring deployment/prometheus 9090:9090
# Visit: http://localhost:9090/alerts
```

**AlertManager UI**:
- Visit: http://34.160.89.136
- Shows all firing alerts
- Allows creating silences

**Grafana**:
- Alerts tab shows alert history
- Dashboards can display alert annotations

### Testing Alerts

**Trigger HighClientErrorRate**:
```bash
# Generate 401 errors by calling without auth
TASK_MANAGER_IP=$(kubectl get ingress task-manager -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

for i in {1..200}; do
  curl -s -o /dev/null http://$TASK_MANAGER_IP/tasks
done
```

**Monitor alert status**:
```bash
kubectl port-forward -n monitoring deployment/prometheus 9090:9090
# Visit: http://localhost:9090/alerts
# Wait 5 minutes for alert to fire
```

### Alert Workflow

```
Metric Threshold Exceeded
         ↓
    [PENDING State]
    (waiting for duration)
         ↓
    Duration Elapsed
         ↓
     [FIRING State]
         ↓
    Sent to AlertManager
         ↓
    (Future: Notifications)
```

---

## Request Tracing

### How It Works

Every HTTP request gets a unique **correlation_id** that follows it through the entire system:

1. **Generation**: Middleware generates 32-character hex UUID
2. **Propagation**: ID added to response header `correlation_id`
3. **Logging**: All log entries include the correlation_id
4. **Searching**: Query Cloud Logging by correlation_id

### Example Flow

```
1. Client makes request
   ↓
2. Middleware generates: correlation_id=a3b2c1d4e5f6g7h8i9j0k1l2m3n4o5p6
   ↓
3. Logger records: "request started" with correlation_id
   ↓
4. Business logic executes (all logs include correlation_id)
   ↓
5. Logger records: "request completed" with correlation_id
   ↓
6. Response sent with header: Correlation_id: a3b2c1d4e5f6g7h8i9j0k1l2m3n4o5p6
```

### Tracing a Request

**Step 1: Make a request and capture correlation_id**:
```bash
TASK_MANAGER_IP=$(kubectl get ingress task-manager -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

curl -i http://$TASK_MANAGER_IP/healthz | grep -i correlation
# Output: correlation_id: a3b2c1d4e5f6g7h8i9j0k1l2m3n4o5p6
```

**Step 2: Search logs by correlation_id**:

Via kubectl:
```bash
CORRELATION_ID="a3b2c1d4e5f6g7h8i9j0k1l2m3n4o5p6"
kubectl logs -l app.kubernetes.io/name=task-manager --tail=1000 | grep "$CORRELATION_ID"
```

Via Cloud Logging:
```bash
gcloud logging read \
  "jsonPayload.correlation_id=\"a3b2c1d4e5f6g7h8i9j0k1l2m3n4o5p6\"" \
  --project=iaasepitech \
  --limit=50 \
  --format=json
```

**Step 3: View complete request lifecycle**:

You'll see logs like:
```json
{
  "time": "2026-01-15T10:30:45.100Z",
  "level": "INFO",
  "msg": "request started",
  "correlation_id": "a3b2c1d4e5f6g7h8i9j0k1l2m3n4o5p6",
  "method": "GET",
  "path": "/healthz",
  "remote_addr": "10.4.0.1"
}
{
  "time": "2026-01-15T10:30:45.102Z",
  "level": "INFO",
  "msg": "request completed",
  "correlation_id": "a3b2c1d4e5f6g7h8i9j0k1l2m3n4o5p6",
  "method": "GET",
  "path": "/healthz",
  "status": 200,
  "duration_ms": 2
}
```

### Implementation Details

**Correlation ID Middleware** (`app/internal/httpapi/middleware/correlation.go`):
- Generates UUID using `crypto/rand`
- Encodes as 32-character hex string
- Sets response header
- Creates request-scoped logger

**Logger** (`app/internal/logger/logger.go`):
- Uses Go's `log/slog` for structured logging
- `WithCorrelationID()` creates child logger with ID attached
- All logs automatically include correlation_id field

---

## Troubleshooting

### Common Issues

#### 1. No metrics in Grafana

**Check Prometheus is scraping**:
```bash
kubectl port-forward -n monitoring deployment/prometheus 9090:9090
# Visit: http://localhost:9090/targets
# Look for task-manager target - should show "UP"
```

**Check metrics endpoint**:
```bash
kubectl port-forward deployment/task-manager 8080:8080
curl http://localhost:8080/metrics
# Should return Prometheus metrics
```

#### 2. Logs not showing correlation_id

**Verify logger is initialized**:
```bash
kubectl logs -l app.kubernetes.io/name=task-manager --tail=10
# Should see JSON logs with correlation_id field
```

**If not, rebuild and deploy**:
```bash
# Rebuild image
cd app
docker build -t <your-registry>/task-manager:latest .
docker push <your-registry>/task-manager:latest

# Restart deployment
kubectl rollout restart deployment/task-manager
```

#### 3. Alerts not firing

**Check alert rules are loaded**:
```bash
kubectl port-forward -n monitoring deployment/prometheus 9090:9090
# Visit: http://localhost:9090/rules
# Should see all 8 alerts
```

**Check AlertManager connection**:
```bash
kubectl exec -n monitoring deployment/prometheus -- \
  wget -qO- http://alertmanager:9093/-/healthy
# Should return "Healthy for AlertManager"
```

#### 4. Cannot access Grafana/AlertManager

**Check ingress IPs**:
```bash
kubectl get ingress -n monitoring
# All should have ADDRESS assigned
```

**Check pods are running**:
```bash
kubectl get pods -n monitoring
# All should be Running
```

### Useful Commands

**Check all monitoring components**:
```bash
kubectl get all -n monitoring
```

**View Prometheus config**:
```bash
kubectl get configmap prometheus-config -n monitoring -o yaml
```

**View alert rules**:
```bash
kubectl get configmap prometheus-config -n monitoring -o yaml | grep -A 50 "alert-rules.yaml"
```

**Restart monitoring components**:
```bash
kubectl rollout restart deployment/prometheus -n monitoring
kubectl rollout restart deployment/alertmanager -n monitoring
kubectl rollout restart deployment/grafana -n monitoring
```

**Check PodMonitoring**:
```bash
kubectl get podmonitoring -A
kubectl describe podmonitoring task-manager -n default
```

---

## Maintenance

### Updating Alert Rules

1. Edit `helm/prometheus-alerts/alert-rules.yaml`
2. Apply changes:
   ```bash
   cd terraform
   terraform apply
   ```
3. Verify rules loaded:
   ```bash
   kubectl port-forward -n monitoring deployment/prometheus 9090:9090
   # Visit: http://localhost:9090/rules
   ```

### Updating Grafana Dashboards

1. Edit `helm/grafana/dashboards/task-manager-overview.json`
2. Apply changes:
   ```bash
   cd terraform
   terraform apply -target=kubernetes_config_map.grafana_dashboards
   ```
3. Restart Grafana:
   ```bash
   kubectl rollout restart deployment/grafana -n monitoring
   ```

### Scaling Monitoring Components

Prometheus and AlertManager are configured with resource limits in `terraform/12-monitoring.tf`:

```hcl
resources {
  requests = {
    cpu    = "100m"
    memory = "512Mi"
  }
  limits = {
    cpu    = "500m"
    memory = "1Gi"
  }
}
```

Adjust these values if needed for your workload.

---

## Files Reference

### Monitoring Infrastructure

- `terraform/12-monitoring.tf` - Prometheus, AlertManager, Grafana, Ingresses
- `helm/prometheus-alerts/alert-rules.yaml` - Alert definitions
- `helm/grafana/dashboards/task-manager-overview.json` - Grafana dashboard

### Application Code

- `app/internal/httpapi/middleware/prometheus.go` - Metrics collection
- `app/internal/httpapi/middleware/correlation.go` - Correlation ID & logging
- `app/internal/logger/logger.go` - Structured logger
- `app/cmd/api/main.go` - Logger initialization

### Documentation

- `MONITORING-README.md` - This file
- `MONITORING-REQUIREMENTS.md` - Implementation guide
- `MONITORING-VERIFICATION.md` - Verification report

---

## Summary

The monitoring system provides complete observability:

- **Real-time metrics** via Prometheus and Grafana
- **Structured logging** with correlation ID tracing
- **Proactive alerting** for resource and application issues
- **Request tracing** for debugging and troubleshooting

All components are deployed via Terraform and fully integrated with your GKE cluster.

**Key URLs**:
- Grafana: http://34.54.54.224 (admin/changeme123)
- AlertManager: http://34.160.89.136
- Prometheus: Port-forward to 9090
- Cloud Logging: https://console.cloud.google.com/logs/query?project=iaasepitech
