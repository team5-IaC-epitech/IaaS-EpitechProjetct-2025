#!/bin/bash

# ============================================================================
# GKE Scalability Test Script
# ============================================================================
#
# This script tests horizontal pod autoscaling (HPA) of your GKE cluster
# by generating controlled load and monitoring pod creation.
#
# USAGE:
#   ./test-scalability.sh                    # Interactive test (default)
#   REQUESTS=15000 CONCURRENCY=80 DURATION=300 ./test-scalability.sh
#
# EXAMPLES:
#
#   Light test (1-2 pods expected):
#     REQUESTS=5000 CONCURRENCY=20 DURATION=120 ./test-scalability.sh
#
#   Medium test (3-5 pods expected):
#     REQUESTS=10000 CONCURRENCY=50 DURATION=300 ./test-scalability.sh
#
#   Heavy test (6-10 pods expected):
#     REQUESTS=20000 CONCURRENCY=100 DURATION=600 ./test-scalability.sh
#
# ENVIRONMENT VARIABLES:
#   INGRESS_IP     - Load balancer IP (default: 136.110.213.157)
#   ENDPOINT       - Endpoint to test (default: /healthz)
#   REQUESTS       - Total number of requests (default: 10000)
#   CONCURRENCY    - Concurrent requests (default: 50)
#   DURATION       - Test duration in seconds (default: 300)
#
# PREREQUISITES:
#   - kubectl configured and connected to cluster
#   - Cluster access: gcloud container clusters get-credentials ...
#   - Tool 'hey' will be installed automatically if needed
#
# PARALLEL MONITORING:
#   In another terminal, run:
#     watch -n 2 'kubectl get hpa,pods -l app.kubernetes.io/name=task-manager'
#
# EXPECTED RESULTS:
#   - Pods scale automatically from 1 → N based on load
#   - HPA reacts when CPU > 70% or Memory > 70%
#   - Stable performance with response time < 100ms (p95)
#   - After test, automatic scale-down after ~5 minutes
#
# ============================================================================

set -e

# Display colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INGRESS_IP="${INGRESS_IP:-34.13.122.235}"
ENDPOINT="${ENDPOINT:-/healthz}"
DEPLOYMENT_NAME="task-manager"
NAMESPACE="default"

# Test parameters (customizable via environment variables)
REQUESTS="${REQUESTS:-10000}"        # Total number of requests
CONCURRENCY="${CONCURRENCY:-50}"     # Concurrent requests
DURATION="${DURATION:-300}"          # Test duration in seconds (5min default)

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  GKE Scalability Test - Task Manager${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to display cluster state
show_cluster_state() {
    echo -e "${YELLOW}Current cluster state:${NC}"
    kubectl get pods -l app.kubernetes.io/name=task-manager -o wide
    echo ""
    kubectl get hpa task-manager 2>/dev/null || echo "HPA not found"
    echo ""
}

# Function to install load testing tool
install_load_tool() {
    if ! command -v hey &> /dev/null; then
        echo -e "${YELLOW}Installing 'hey' (load testing tool)...${NC}"

        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            if command -v brew &> /dev/null; then
                brew install hey
            else
                echo -e "${RED}Homebrew not installed. Manual installation...${NC}"
                curl -sL https://github.com/rakyll/hey/releases/download/v0.1.4/hey_darwin_amd64 -o /tmp/hey
                chmod +x /tmp/hey
                sudo mv /tmp/hey /usr/local/bin/hey
            fi
        else
            # Linux
            curl -sL https://github.com/rakyll/hey/releases/download/v0.1.4/hey_linux_amd64 -o /tmp/hey
            chmod +x /tmp/hey
            sudo mv /tmp/hey /usr/local/bin/hey
        fi

        echo -e "${GREEN}✓ 'hey' successfully installed${NC}"
        echo ""
    fi
}

# Function for real-time monitoring
monitor_scaling() {
    echo -e "${BLUE}Monitoring autoscaling (Ctrl+C to stop)...${NC}"
    echo ""

    local start_time=$(date +%s)
    local max_pods=0

    while true; do
        clear
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}  Monitoring - ${elapsed}s elapsed${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo ""

        # Display pods
        echo -e "${YELLOW}Active pods:${NC}"
        local pod_count=$(kubectl get pods -l app.kubernetes.io/name=task-manager -o json | jq '[.items[] | select(.status.phase=="Running")] | length')
        kubectl get pods -l app.kubernetes.io/name=task-manager -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.phase,\
READY:.status.containerStatuses[0].ready,\
CPU:.spec.containers[0].resources.requests.cpu,\
MEMORY:.spec.containers[0].resources.requests.memory,\
NODE:.spec.nodeName

        echo ""
        echo -e "${GREEN}Running pods count: $pod_count${NC}"

        if [ "$pod_count" -gt "$max_pods" ]; then
            max_pods=$pod_count
        fi
        echo -e "${GREEN}Maximum pods reached: $max_pods${NC}"

        echo ""

        # Display HPA
        echo -e "${YELLOW}Horizontal Pod Autoscaler:${NC}"
        kubectl get hpa task-manager 2>/dev/null || echo "HPA not available"

        echo ""

        # Display metrics
        echo -e "${YELLOW}Pods metrics:${NC}"
        kubectl top pods -l app.kubernetes.io/name=task-manager 2>/dev/null || echo "Metrics not available (wait ~30s after startup)"

        sleep 5
    done
}

# Load test function
run_load_test() {
    local url="http://${INGRESS_IP}${ENDPOINT}"

    echo -e "${YELLOW}Test configuration:${NC}"
    echo "  URL: $url"
    echo "  Total requests: $REQUESTS"
    echo "  Concurrency: $CONCURRENCY"
    echo "  Duration: ${DURATION}s"
    echo ""

    echo -e "${YELLOW}Starting load test...${NC}"
    echo ""

    # Run test with hey
    hey -n "$REQUESTS" -c "$CONCURRENCY" -z "${DURATION}s" "$url" > /tmp/load_test_results.txt 2>&1

    echo -e "${GREEN}✓ Load test completed${NC}"
    echo ""

    # Display results
    cat /tmp/load_test_results.txt
}

# Main function
main() {
    echo -e "${YELLOW}1. Checking cluster access...${NC}"
    if ! kubectl get pods &> /dev/null; then
        echo -e "${RED}✗ Unable to access Kubernetes cluster${NC}"
        echo "Run: gcloud container clusters get-credentials team5-gke-cluster --region europe-west9 --project iaasepitech"
        exit 1
    fi
    echo -e "${GREEN}✓ Cluster accessible${NC}"
    echo ""

    echo -e "${YELLOW}2. Initial cluster state:${NC}"
    show_cluster_state

    echo -e "${YELLOW}3. Checking API access...${NC}"
    if curl -s -f "http://${INGRESS_IP}${ENDPOINT}" > /dev/null; then
        echo -e "${GREEN}✓ API accessible at http://${INGRESS_IP}${ENDPOINT}${NC}"
    else
        echo -e "${RED}✗ API not accessible. Check IP: ${INGRESS_IP}${NC}"
        exit 1
    fi
    echo ""

    # Install test tool
    install_load_tool

    # Propose options
    echo -e "${BLUE}Choose an option:${NC}"
    echo "  1) Run load test AND monitoring (recommended)"
    echo "  2) Run monitoring only"
    echo "  3) Run load test only"
    echo ""
    read -p "Your choice (1-3): " choice

    case $choice in
        1)
            # Launch monitoring in background in a new terminal
            echo -e "${YELLOW}Opening monitoring in a new terminal...${NC}"

            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS - open in new terminal
                osascript -e "tell app \"Terminal\" to do script \"cd $(pwd) && bash $0 monitor\""
            else
                # Linux - try gnome-terminal or xterm
                if command -v gnome-terminal &> /dev/null; then
                    gnome-terminal -- bash -c "$0 monitor; exec bash"
                elif command -v xterm &> /dev/null; then
                    xterm -e "$0 monitor" &
                else
                    echo -e "${YELLOW}Unable to open a new terminal automatically.${NC}"
                    echo "Run manually in another terminal: $0 monitor"
                fi
            fi

            sleep 3
            run_load_test
            ;;
        2)
            monitor_scaling
            ;;
        3)
            run_load_test
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Test completed!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Final cluster state:${NC}"
    show_cluster_state
}

# Entry point
if [ "$1" = "monitor" ]; then
    monitor_scaling
else
    main
fi
