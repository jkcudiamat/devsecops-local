#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────
# Script 05: Offensive Security Testing (Local)
# Run from your HOST machine (Mac/Linux) — attacks the Minikube app
# to validate Falco detection is working.
#
# NOTE: This is attacking YOUR OWN system. Only do this against
# systems you own and control. This is legal and educational.
#
# Usage: bash scripts/05-attack.sh
# ─────────────────────────────────────────────────────────

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Pick up the app URL saved by the deploy script
APP_URL=${1:-$(cat /tmp/devsecops-app-url 2>/dev/null || minikube service devsecops-app-service --url 2>/dev/null)}

if [ -z "$APP_URL" ]; then
    echo "Could not determine app URL."
    echo "Usage: bash scripts/05-attack.sh http://MINIKUBE_IP:30080"
    exit 1
fi

# Extract just the host/IP for Nmap
TARGET=$(echo "$APP_URL" | sed 's|http://||' | cut -d: -f1)
PORT=$(echo "$APP_URL" | sed 's|http://||' | cut -d: -f2)

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_DIR="docs/attack-report-$TIMESTAMP"
mkdir -p "$REPORT_DIR"

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Offensive Security Test — Local Lab${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo "  Target:  $APP_URL"
echo "  Reports: $REPORT_DIR/"
echo ""
echo -e "${YELLOW}  Watch Falco in another terminal:${NC}"
echo "  kubectl logs -n falco -l app.kubernetes.io/name=falco -f"
echo ""
read -p "  Press ENTER to begin attack sequence..."

# ─── Phase 1: Verify app is live ──────────────────────────
echo ""
echo -e "${CYAN}▶ [1/5] Basic connectivity & response...${NC}"
curl -s "$APP_URL/" | tee "$REPORT_DIR/01-home-response.txt"
curl -s "$APP_URL/health" | tee "$REPORT_DIR/01-health-response.txt"
curl -s "$APP_URL/info" | tee "$REPORT_DIR/01-info-response.txt"

# ─── Phase 2: Port scan ───────────────────────────────────
echo ""
echo -e "${CYAN}▶ [2/5] Nmap port scan (runs if nmap is installed)...${NC}"
if command -v nmap &>/dev/null; then
    nmap -sV -p- --open "$TARGET" | tee "$REPORT_DIR/02-nmap-scan.txt"
    echo -e "${GREEN}✓ Nmap scan complete${NC}"
else
    echo "  nmap not found — install with: brew install nmap (or apt install nmap)"
    echo "  Skipping nmap scan."
fi

# ─── Phase 3: Web app probes ──────────────────────────────
echo ""
echo -e "${CYAN}▶ [3/5] Web application attack probes...${NC}"

echo "  -> Path traversal..."
curl -s "$APP_URL/../../../etc/passwd" >> "$REPORT_DIR/03-web-probes.txt" 2>&1
curl -s "$APP_URL/.env" >> "$REPORT_DIR/03-web-probes.txt" 2>&1
curl -s "$APP_URL/admin" >> "$REPORT_DIR/03-web-probes.txt" 2>&1
curl -s "$APP_URL/config" >> "$REPORT_DIR/03-web-probes.txt" 2>&1

echo "  -> SQL injection..."
curl -s "$APP_URL/?id=1'OR'1'='1" >> "$REPORT_DIR/03-web-probes.txt" 2>&1
curl -s "$APP_URL/login?u=admin'--" >> "$REPORT_DIR/03-web-probes.txt" 2>&1

echo "  -> XSS probes..."
curl -s "$APP_URL/?q=<script>alert(1)</script>" >> "$REPORT_DIR/03-web-probes.txt" 2>&1

echo "  -> Verbose HTTP methods..."
curl -s -X TRACE "$APP_URL/" >> "$REPORT_DIR/03-web-probes.txt" 2>&1
curl -s -X OPTIONS "$APP_URL/" -i >> "$REPORT_DIR/03-web-probes.txt" 2>&1

echo "  -> Missing security headers check..."
curl -s -I "$APP_URL/" | tee "$REPORT_DIR/03-headers.txt"

echo -e "${GREEN}✓ Web probes complete — saved to $REPORT_DIR/03-web-probes.txt${NC}"

# ─── Phase 4: Container shell spawn (key Falco trigger) ───
echo ""
echo -e "${CYAN}▶ [4/5] Spawning shell inside pod (Falco should fire!)...${NC}"
POD=$(kubectl get pods -l app=devsecops-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -n "$POD" ]; then
    echo "  Target pod: $POD"
    echo "  Running: kubectl exec $POD -- /bin/sh -c 'id && hostname && cat /etc/os-release'"
    kubectl exec "$POD" -- /bin/sh -c 'id && hostname && cat /etc/os-release' \
        | tee "$REPORT_DIR/04-container-exec.txt" 2>&1 || true
    echo -e "${YELLOW}  Falco should have fired a CRITICAL alert for this!${NC}"
else
    echo "  No running pod found. Skipping."
fi

# ─── Phase 5: Check what Falco caught ─────────────────────
echo ""
echo -e "${CYAN}▶ [5/5] Collecting Falco detection evidence...${NC}"
sleep 5  # Give Falco a moment to write logs

kubectl logs -n falco -l app.kubernetes.io/name=falco --since=10m \
    | grep -E "Warning|Error|Critical|ALERT" \
    | tee "$REPORT_DIR/05-falco-alerts.txt" || true

ALERT_COUNT=$(wc -l < "$REPORT_DIR/05-falco-alerts.txt" 2>/dev/null || echo 0)

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Attack sequence complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo ""
echo "  Falco alerts caught: $ALERT_COUNT"
echo "  Full reports saved:  $REPORT_DIR/"
echo ""
echo -e "${YELLOW}  Now document your findings:${NC}"
echo "  1. Open docs/threat-findings.md and fill it in"
echo "  2. Screenshot Falco logs and paste findings in"
echo "  3. git add . && git commit -m 'docs: add offensive testing findings'"
echo ""
