#!/usr/bin/env bash
# =============================================================================
# check-services.sh — Service Status Checker
# AWS EC2 Infrastructure Monitoring Stack
# =============================================================================
#
# Usage:
#   chmod +x check-services.sh
#   ./check-services.sh
#
# Run on the Monitoring EC2 to check Prometheus, Grafana, and Alertmanager.
# Run on the Monitored EC2 to check Node Exporter.
#
# =============================================================================

set -euo pipefail

# Colour codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Colour

# Services to check
# Adjust the list depending on which server this script runs on
MONITORING_SERVICES=("prometheus" "grafana-server" "alertmanager")
MONITORED_SERVICES=("node_exporter")

print_header() {
  echo ""
  echo "============================================================"
  echo "  AWS EC2 Monitoring Stack — Service Status Check"
  echo "  $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "============================================================"
  echo ""
}

check_service() {
  local service_name="$1"
  if systemctl is-active --quiet "$service_name" 2>/dev/null; then
    echo -e "  ${GREEN}[ACTIVE]${NC}   $service_name"
  elif systemctl list-unit-files --quiet "$service_name.service" &>/dev/null; then
    echo -e "  ${RED}[INACTIVE]${NC} $service_name"
  else
    echo -e "  ${YELLOW}[NOT FOUND]${NC} $service_name — service unit not installed"
  fi
}

print_header

echo "--- Monitoring Server Services ---"
for svc in "${MONITORING_SERVICES[@]}"; do
  check_service "$svc"
done

echo ""
echo "--- Monitored Server Services ---"
for svc in "${MONITORED_SERVICES[@]}"; do
  check_service "$svc"
done

echo ""
echo "============================================================"
echo ""
