#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────
# Script 00: Verify all required tools are installed
# Usage: bash scripts/00-check-env.sh
# ─────────────────────────────────────────────────────────

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
    local name=$1
    local cmd=$2
    if command -v "$cmd" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $name"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}✗${NC} $name — not found"
        FAIL=$((FAIL + 1))
    fi
}

echo ""
echo "Checking required tools..."
echo "────────────────────────────"
check "minikube"  minikube
check "kubectl"   kubectl
check "helm"      helm
check "docker"    docker
check "git"       git
check "checkov"   checkov
check "trivy"     trivy
check "nmap"      nmap
echo "────────────────────────────"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}All tools present. Ready to run.${NC}"
    echo ""
    echo "  Next: bash scripts/01-start-minikube.sh"
else
    echo -e "${YELLOW}Missing $FAIL tool(s). Install them, then re-run this script.${NC}"
    echo ""
    echo "  macOS:  brew install minikube kubectl helm checkov trivy nmap"
    echo "          brew install --cask docker"
    echo ""
    echo "  WSL2:   sudo apt install -y kubectl helm docker.io nmap"
    echo "          pip install checkov"
    echo "          # Install minikube + trivy separately (see README)"
fi
echo ""
