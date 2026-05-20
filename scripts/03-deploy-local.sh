#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────
# Script 03: Deploy the app to Minikube
# Usage: bash scripts/03-deploy-local.sh YOUR_DOCKERHUB_USERNAME
# ─────────────────────────────────────────────────────────

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DOCKERHUB_USERNAME=${1:-"jakeoni25"}

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Deploying to Minikube${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo ""

# Create namespace first
kubectl apply -f k8s/namespace.yaml

# Update image reference in deployment (non-destructive sed)
sed "s|DOCKERHUB_USERNAME|$DOCKERHUB_USERNAME|g" k8s/deployment.yaml \
    | kubectl apply -n devsecops -f -

kubectl apply -n devsecops -f k8s/service.yaml
kubectl apply -n devsecops -f k8s/network-policy.yaml

echo ""
echo -e "${CYAN}  Waiting for rollout...${NC}"
kubectl rollout status deployment/devsecops-app -n devsecops --timeout=120s

echo ""
echo -e "${GREEN}✓ Deployment complete${NC}"
echo ""
echo "  Pods:"
kubectl get pods -l app=devsecops-app -n devsecops
echo ""

# Save the service URL for use by 05-attack.sh
APP_URL=$(minikube service devsecops-app-service -n devsecops --url 2>/dev/null)
echo "$APP_URL" > /tmp/devsecops-app-url

echo -e "${GREEN}  App is live at: $APP_URL${NC}"
echo ""
echo -e "${YELLOW}  Quick smoke test:${NC}"
curl -s "$APP_URL/health" && echo ""
echo ""
echo "  Next: bash scripts/04-install-security-tools.sh"
echo ""
