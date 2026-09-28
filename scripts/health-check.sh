#!/usr/bin/env bash
# =============================================================================
# health-check.sh — Endpoint Health Checker
# AWS EC2 Infrastructure Monitoring Stack
# =============================================================================
#
# Usage:
#   chmod +x health-check.sh
#   ./health-check.sh
#
# Run on the Monitoring EC2 to verify all service HTTP endpoints are reachable.
#
# CONFIGURATION:
#   Set MONITORED_IP to the private IP of your Node Exporter EC2 instance.
#
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# CONFIGURATION — Update MONITORED_IP before running
# ---------------------------------------------------------------------------
MONITORED_IP="${MONITORED_SERVER_PRIVATE_IP:-MONITORED_SERVER_PRIVATE_IP}"
TIMEOUT=5

# Colour codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# ---------------------------------------------------------------------------

print_header() {
  echo ""
  echo "============================================================"
  echo "  AWS EC2 Monitoring Stack — Endpoint Health Check"
  echo "  $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "============================================================"
  echo ""
}

check_endpoint() {
  local label="$1"
  local url="$2"
  local http_code

  http_code=$(curl --silent --output /dev/null --write-out "%{http_code}" \
    --max-time "$TIMEOUT" "$url" 2>/dev/null || true)

  if [[ "$http_code" == "200" ]]; then
    echo -e "  ${GREEN}[OK]${NC}   $label — $url (HTTP $http_code)"
  else
    echo -e "  ${RED}[FAIL]${NC} $label — $url (HTTP ${http_code:-TIMEOUT/NO RESPONSE})"
  fi
}

print_header

echo "--- Monitoring Server Endpoints ---"
check_endpoint "Prometheus UI"     "http://localhost:9090/-/healthy"
check_endpoint "Grafana UI"        "http://localhost:3000/api/health"
check_endpoint "Alertmanager UI"   "http://localhost:9093/-/healthy"

echo ""
echo "--- Monitored Server Endpoints ---"
if [[ "$MONITORED_IP" == "MONITORED_SERVER_PRIVATE_IP" ]]; then
  echo "  [SKIP] Node Exporter — Set MONITORED_SERVER_PRIVATE_IP environment variable first."
  echo "         Example: MONITORED_SERVER_PRIVATE_IP=10.0.1.45 ./health-check.sh"
else
  check_endpoint "Node Exporter Metrics" "http://${MONITORED_IP}:9100/metrics"
fi

echo ""
echo "============================================================"
echo ""
