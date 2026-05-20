#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────
# Script 06: Stop Minikube (state is preserved on disk)
# Usage: bash scripts/06-stop.sh
# ─────────────────────────────────────────────────────────

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "  Stopping Minikube (your data is preserved)..."
minikube stop

echo ""
echo -e "${GREEN}✓ Minikube stopped${NC}"
echo ""
echo -e "${YELLOW}  To resume:  minikube start${NC}"
echo "  To delete:   minikube delete  (destroys all cluster state)"
echo ""
