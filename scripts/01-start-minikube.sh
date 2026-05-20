#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────
# Script 01: Start Minikube with the right configuration
# Usage: bash scripts/01-start-minikube.sh
# ─────────────────────────────────────────────────────────

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m'

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Starting Minikube${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo ""

# Start with enough resources for Falco + Prometheus + app
minikube start \
    --cpus=4 \
    --memory=6g \
    --disk-size=20g \
    --driver=docker \
    --addons=metrics-server

echo ""
echo -e "${GREEN}✓ Minikube started${NC}"
echo ""

# Enable ingress addon (optional — useful for later)
minikube addons enable ingress 2>/dev/null || true

echo "  Cluster info:"
kubectl cluster-info
echo ""
echo "  Nodes:"
kubectl get nodes
echo ""
echo -e "${GREEN}  Ready. Next: bash scripts/02-build-and-push.sh YOUR_DOCKERHUB_USERNAME${NC}"
echo ""
