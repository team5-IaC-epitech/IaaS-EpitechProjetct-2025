#!/bin/bash

# Deploy Monitoring Stack for Task Manager
# This script deploys Grafana with GCP Managed Prometheus integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="iaasepitech"
CLUSTER_NAME="team5-gke-cluster-dev"
REGION="europe-west9"
MONITORING_NAMESPACE="monitoring"

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Task Manager Monitoring Deployment${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI is not installed${NC}"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo -e "${RED}Error: helm is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites installed${NC}"
echo ""

# Get GKE credentials
echo -e "${YELLOW}Getting GKE credentials...${NC}"
gcloud container clusters get-credentials "$CLUSTER_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID"

echo -e "${GREEN}✓ GKE credentials configured${NC}"
echo ""

# Verify GCP Managed Prometheus is enabled
echo -e "${YELLOW}Verifying GCP Managed Prometheus...${NC}"
if kubectl get namespace gmp-system &> /dev/null; then
    echo -e "${GREEN}✓ GCP Managed Prometheus is enabled${NC}"
else
    echo -e "${RED}Error: GCP Managed Prometheus is not enabled on the cluster${NC}"
    echo -e "${YELLOW}Please run 'terraform apply' to enable it${NC}"
    exit 1
fi
echo ""

# Create monitoring namespace
echo -e "${YELLOW}Creating monitoring namespace...${NC}"
kubectl create namespace "$MONITORING_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Monitoring namespace ready${NC}"
echo ""

# Add Grafana Helm repository
echo -e "${YELLOW}Adding Grafana Helm repository...${NC}"
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
echo -e "${GREEN}✓ Grafana Helm repository added${NC}"
echo ""

# Deploy Grafana
echo -e "${YELLOW}Deploying Grafana...${NC}"
cd "$(dirname "$0")/../helm/grafana"
helm dependency update
helm upgrade --install grafana . \
    --namespace "$MONITORING_NAMESPACE" \
    --create-namespace \
    --values values.yaml \
    --wait \
    --timeout 10m

echo -e "${GREEN}✓ Grafana deployed successfully${NC}"
echo ""

# Deploy/Upgrade Task Manager with monitoring
echo -e "${YELLOW}Deploying Task Manager with monitoring enabled...${NC}"
cd "../task-manager"
helm upgrade --install task-manager . \
    --namespace default \
    --create-namespace \
    --values values.yaml \
    --wait \
    --timeout 10m

echo -e "${GREEN}✓ Task Manager deployed successfully${NC}"
echo ""

# Wait for Grafana ingress
echo -e "${YELLOW}Waiting for Grafana ingress IP...${NC}"
echo "This may take 5-10 minutes for the GCP Load Balancer to provision..."

TIMEOUT=600
ELAPSED=0
SLEEP_INTERVAL=10

while [ $ELAPSED -lt $TIMEOUT ]; do
    GRAFANA_IP=$(kubectl get ingress grafana -n "$MONITORING_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

    if [ -n "$GRAFANA_IP" ]; then
        echo -e "${GREEN}✓ Grafana ingress IP assigned: $GRAFANA_IP${NC}"
        break
    fi

    echo -n "."
    sleep $SLEEP_INTERVAL
    ELAPSED=$((ELAPSED + SLEEP_INTERVAL))
done

if [ -z "$GRAFANA_IP" ]; then
    echo ""
    echo -e "${YELLOW}Warning: Grafana ingress IP not assigned yet${NC}"
    echo "Run the following command to check status:"
    echo "  kubectl get ingress grafana -n $MONITORING_NAMESPACE"
else
    echo ""
    echo -e "${GREEN}======================================${NC}"
    echo -e "${GREEN}Deployment Complete!${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo ""
    echo -e "${GREEN}Grafana Dashboard:${NC}"
    echo -e "  URL: http://$GRAFANA_IP"
    echo -e "  Username: admin"
    echo -e "  Password: changeme123"
    echo ""
    echo -e "${YELLOW}Important: Change the default password after first login!${NC}"
    echo ""
    echo -e "${GREEN}Pre-configured Dashboard:${NC}"
    echo -e "  Navigate to: Dashboards → Browse → Task Manager - Overview"
    echo ""
    echo -e "${GREEN}Next Steps:${NC}"
    echo "  1. Log in to Grafana"
    echo "  2. Open the 'Task Manager - Overview' dashboard"
    echo "  3. Generate some test traffic to see metrics"
    echo ""
    echo -e "${GREEN}Generate test traffic:${NC}"
    echo "  TASK_MANAGER_IP=\$(kubectl get ingress task-manager -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
    echo "  for i in {1..100}; do curl -s -o /dev/null http://\$TASK_MANAGER_IP/healthz; done"
    echo ""
fi

# Show monitoring resources
echo -e "${GREEN}Monitoring Resources:${NC}"
echo ""
kubectl get all -n "$MONITORING_NAMESPACE"
echo ""
kubectl get podmonitoring -n default
echo ""

echo -e "${GREEN}For troubleshooting, see: MONITORING.md${NC}"
