#!/bin/bash

# Monitoring Verification Script
# This script verifies all monitoring requirements are met

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "  Monitoring Requirements Verification"
echo "========================================"
echo ""

# 1. Check Monitoring Pods
echo -e "${YELLOW}1. Checking monitoring pods...${NC}"
kubectl get pods -n monitoring
echo ""

if kubectl get pods -n monitoring | grep -q "Running"; then
    echo -e "${GREEN}✓ Monitoring pods are running${NC}"
else
    echo -e "${RED}✗ Some monitoring pods are not running${NC}"
fi
echo ""

# 2. Check Prometheus Alert Rules
echo -e "${YELLOW}2. Checking Prometheus alert rules...${NC}"
kubectl port-forward -n monitoring deployment/prometheus 9090:9090 > /dev/null 2>&1 &
PF_PID=$!
sleep 3

RULES_COUNT=$(curl -s http://localhost:9090/api/v1/rules | jq '.data.groups | length')
echo "Found $RULES_COUNT alert rule groups"

if [ "$RULES_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Alert rules are loaded${NC}"
    curl -s http://localhost:9090/api/v1/rules | jq -r '.data.groups[].rules[].alert' | sed 's/^/  - /'
else
    echo -e "${RED}✗ No alert rules found${NC}"
fi

kill $PF_PID 2>/dev/null
echo ""

# 3. Check AlertManager
echo -e "${YELLOW}3. Checking AlertManager...${NC}"
kubectl port-forward -n monitoring deployment/alertmanager 9093:9093 > /dev/null 2>&1 &
AM_PID=$!
sleep 3

if curl -s http://localhost:9093/-/healthy | grep -q "Healthy"; then
    echo -e "${GREEN}✓ AlertManager is healthy${NC}"
else
    echo -e "${RED}✗ AlertManager is not healthy${NC}"
fi

kill $AM_PID 2>/dev/null
echo ""

# 4. Check Prometheus Metrics Scraping
echo -e "${YELLOW}4. Checking if Prometheus is scraping task-manager metrics...${NC}"
kubectl port-forward -n monitoring deployment/prometheus 9090:9090 > /dev/null 2>&1 &
PF_PID=$!
sleep 3

TARGETS=$(curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.job=="task-manager") | .health')
if [ -n "$TARGETS" ]; then
    echo -e "${GREEN}✓ Prometheus is scraping task-manager metrics${NC}"
    echo "  Status: $TARGETS"
else
    echo -e "${RED}✗ Prometheus is not scraping task-manager metrics${NC}"
fi

kill $PF_PID 2>/dev/null
echo ""

# 5. Check PodMonitoring
echo -e "${YELLOW}5. Checking PodMonitoring resource...${NC}"
if kubectl get podmonitoring task-manager -n default > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PodMonitoring resource exists${NC}"
    kubectl get podmonitoring task-manager -n default
else
    echo -e "${RED}✗ PodMonitoring resource not found${NC}"
fi
echo ""

# 6. Check Grafana
echo -e "${YELLOW}6. Checking Grafana...${NC}"
GRAFANA_IP=$(kubectl get ingress grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -n "$GRAFANA_IP" ]; then
    echo -e "${GREEN}✓ Grafana is accessible${NC}"
    echo "  URL: http://$GRAFANA_IP"
    echo "  Username: admin"
    echo "  Password: changeme123"
else
    echo -e "${RED}✗ Grafana ingress IP not assigned${NC}"
fi
echo ""

# 7. Check Task Manager App
echo -e "${YELLOW}7. Checking task-manager application...${NC}"
POD=$(kubectl get pods -l app.kubernetes.io/name=task-manager -o jsonpath='{.items[0].metadata.name}')
echo "Pod: $POD"
echo "Logs (last 5 lines):"
kubectl logs $POD --tail=5
echo ""

# 8. Test correlation_id
echo -e "${YELLOW}8. Testing correlation_id in logs...${NC}"
TASK_MANAGER_IP=$(kubectl get ingress task-manager -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -n "$TASK_MANAGER_IP" ]; then
    echo "Making test request to http://$TASK_MANAGER_IP/healthz"
    CORRELATION_ID=$(curl -s -D - http://$TASK_MANAGER_IP/healthz | grep -i correlation_id | awk '{print $2}' | tr -d '\r')

    if [ -n "$CORRELATION_ID" ]; then
        echo -e "${GREEN}✓ correlation_id found in response header${NC}"
        echo "  correlation_id: $CORRELATION_ID"

        # Check if it appears in logs
        sleep 2
        if kubectl logs $POD --tail=50 | grep -q "$CORRELATION_ID"; then
            echo -e "${GREEN}✓ correlation_id found in application logs${NC}"
        else
            echo -e "${YELLOW}⚠ correlation_id not yet in logs (may need app rebuild)${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ correlation_id not found in response header (may need app rebuild)${NC}"
    fi
else
    echo -e "${RED}✗ Task Manager ingress IP not found${NC}"
fi
echo ""

# Summary
echo "========================================"
echo "  Verification Summary"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. If app logs don't show structured JSON logging, rebuild and deploy:"
echo "   cd app && docker build -t <your-image> . && docker push <your-image>"
echo "   kubectl rollout restart deployment/task-manager"
echo ""
echo "2. Access Grafana dashboard:"
echo "   http://$GRAFANA_IP"
echo ""
echo "3. View Prometheus alerts:"
echo "   kubectl port-forward -n monitoring deployment/prometheus 9090:9090"
echo "   Visit: http://localhost:9090/alerts"
echo ""
echo "4. View AlertManager UI:"
echo "   kubectl port-forward -n monitoring deployment/alertmanager 9093:9093"
echo "   Visit: http://localhost:9093"
echo ""
