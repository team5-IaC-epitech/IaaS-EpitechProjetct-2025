#!/bin/bash
set -e

# This is a script for Endpoint Load Testing

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration

INGRESS_IP="${INGRESS_IP:-136.110.213.157}"
BASE_URL="${BASE_URL:-http://${INGRESS_IP}${ENDPOINTS}}"
ENDPOINTS="${ENDPOINTS:-/healthz}"
REQUESTS="${REQUESTS:-10000}"
CONCURRENCY="${CONCURRENCY:-50}"
DURATION="${DURATION:-300}"

# Checks 

if ! command -v hey &>/dev/null; then
  echo -e "${YELLOW}Installing 'hey' load testing tool...${NC}"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    brew install hey
  else
    curl -sL https://github.com/rakyll/hey/releases/download/v0.1.4/hey_linux_amd64 -o /tmp/hey
    chmod +x /tmp/hey
    sudo mv /tmp/hey /usr/local/bin/hey
  fi
fi

# Starting action here

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Endpoint Load Testing (Error-aware)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Base URL    : $BASE_URL"
echo "  Endpoints   : $ENDPOINTS"
echo "  Requests    : $REQUESTS"
echo "  Concurrency : $CONCURRENCY"
echo "  Duration    : ${DURATION}s"
echo ""

# Load Testing

declare -A PIDS
declare -A LOGS

for endpoint in $ENDPOINTS; do
  URL="${BASE_URL}${endpoint}"
  LOG="/tmp/hey$(echo "$endpoint" | tr '/' '_').log"

  LOGS["$endpoint"]="$LOG"

  echo -e "${YELLOW}Load Testing ${URL}${NC}"

  hey \
    -n "$REQUESTS" \
    -c "$CONCURRENCY" \
    -z "${DURATION}s" \
    "$URL" \
    > "$LOG" 2>&1 &

  PIDS["$endpoint"]=$!
done

echo ""
echo -e "${GREEN}Load generation started${NC}"
echo -e "${BLUE}Observe Prometheus / Grafana dashboards now${NC}"
echo ""

for pid in "${PIDS[@]}"; do
  wait "$pid"
done

# Error checking

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Error Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

EXIT_CODE=0

for endpoint in $ENDPOINTS; do
  LOG="${LOGS[$endpoint]}"

  echo -e "${YELLOW}Endpoint: ${endpoint}${NC}"

  if grep -q "Status code distribution" "$LOG"; then
    awk '
      /Status code distribution:/ {flag=1; next}
      /^[[:space:]]*$/ {flag=0}
      flag {print}
    ' "$LOG"
  else
    echo "  No status code data found"
  fi

  # Error detection

  ERR_401=$(grep -E "^\s*\[401\]" "$LOG" | awk '{print $2}' || echo 0)
  ERR_403=$(grep -E "^\s*\[403\]" "$LOG" | awk '{print $2}' || echo 0)
  ERR_5XX=$(grep -E "^\s*\[5[0-9]{2}\]" "$LOG" | awk '{sum+=$2} END {print sum+0}')

  if [[ "$ERR_401" -gt 0 ]]; then
    echo -e "${RED}  ⚠ 401 Unauthorized: $ERR_401 requests${NC}"
    EXIT_CODE=1
  fi

  if [[ "$ERR_403" -gt 0 ]]; then
    echo -e "${RED}  ⚠ 403 Forbidden: $ERR_403 requests${NC}"
    EXIT_CODE=1
  fi

  if [[ "$ERR_5XX" -gt 0 ]]; then
    echo -e "${RED}  ⚠ 5xx Server errors: $ERR_5XX requests${NC}"
    EXIT_CODE=1
  fi

  echo ""
done

# Final status

if [[ "$EXIT_CODE" -eq 0 ]]; then
  echo -e "${GREEN}✓ No critical HTTP errors detected${NC}"
else
  echo -e "${RED}✗ Errors detected during bombardment${NC}"
fi

exit "$EXIT_CODE"
