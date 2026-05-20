#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────
# Script 04: Install Falco + Prometheus + Grafana on Minikube
# Usage: bash scripts/04-install-security-tools.sh
# ─────────────────────────────────────────────────────────

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Installing Runtime Security Stack${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo ""

# ─── Falco ────────────────────────────────────────────────
echo -e "${CYAN}▶ [1/2] Installing Falco (runtime threat detection)...${NC}"

helm repo add falcosecurity https://falcosecurity.github.io/charts 2>/dev/null || true
helm repo update

# On Minikube we use the userspace driver (no kernel module needed)
helm upgrade --install falco falcosecurity/falco \
    --namespace falco \
    --create-namespace \
    --set driver.kind=modern_ebpf \
    --set falcosidekick.enabled=true \
    --set falcosidekick.webui.enabled=true \
    --set "customRules.custom-rules\.yaml=$(cat falco/custom-rules.yaml)" \
    --wait --timeout 3m

echo -e "${GREEN}✓ Falco installed${NC}"

# ─── Prometheus + Grafana ─────────────────────────────────
echo ""
echo -e "${CYAN}▶ [2/2] Installing Prometheus + Grafana (observability)...${NC}"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update

helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --create-namespace \
    --set grafana.adminPassword=devsecops123 \
    --set prometheus.prometheusSpec.retention=2h \
    --wait --timeout 5m

echo -e "${GREEN}✓ Prometheus + Grafana installed${NC}"

# ─── Summary ──────────────────────────────────────────────
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Security stack is running!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo ""
echo "  All pods:"
kubectl get pods -n falco
kubectl get pods -n monitoring
echo ""
echo -e "${YELLOW}  To view Falco alerts live:${NC}"
echo "    kubectl logs -n falco -l app.kubernetes.io/name=falco -f"
echo ""
echo -e "${YELLOW}  To open Grafana dashboard:${NC}"
echo "    kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3000:80"
echo "    Open http://localhost:3000  (admin / devsecops123)"
echo ""
echo -e "${YELLOW}  To open Falco Web UI:${NC}"
echo "    kubectl port-forward -n falco svc/falco-falcosidekick-ui 2802:2802"
echo "    Open http://localhost:2802"
echo ""
echo "  Next: bash scripts/05-attack.sh"
echo ""
