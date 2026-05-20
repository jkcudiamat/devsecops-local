#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────
# Script 02: Build image, scan it locally, push to Docker Hub
# Usage: bash scripts/02-build-and-push.sh YOUR_DOCKERHUB_USERNAME
# ─────────────────────────────────────────────────────────

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

DOCKERHUB_USERNAME=${1:-""}
IMAGE_NAME="devsecops-app"
IMAGE_TAG="latest"

if [ -z "$DOCKERHUB_USERNAME" ]; then
    echo -e "${RED}Error: Docker Hub username required.${NC}"
    echo "  Usage: bash scripts/02-build-and-push.sh YOUR_DOCKERHUB_USERNAME"
    exit 1
fi

FULL_IMAGE="$DOCKERHUB_USERNAME/$IMAGE_NAME:$IMAGE_TAG"

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Build → Scan → Push${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
echo "  Image: $FULL_IMAGE"
echo ""

# ─── Step 1: Checkov scan ─────────────────────────────────
echo -e "${CYAN}▶ [1/3] Checkov — IaC & Dockerfile scan...${NC}"
checkov -d . --framework dockerfile,kubernetes --quiet || {
    echo -e "${RED}Checkov found issues. Review above before pushing.${NC}"
    read -p "  Continue anyway? (y/N) " yn
    [[ "$yn" == "y" || "$yn" == "Y" ]] || exit 1
}
echo -e "${GREEN}✓ Checkov passed${NC}"

# ─── Step 2: Build ────────────────────────────────────────
echo ""
echo -e "${CYAN}▶ [2/3] Building Docker image...${NC}"
docker build -t "$FULL_IMAGE" ./app/
echo -e "${GREEN}✓ Build complete${NC}"

# ─── Step 3: Trivy scan ───────────────────────────────────
echo ""
echo -e "${CYAN}▶ [3/3] Trivy — CVE scan (CRITICAL/HIGH)...${NC}"
trivy image --exit-code 1 --ignore-unfixed \
    --vuln-type os,library \
    --severity CRITICAL,HIGH \
    "$FULL_IMAGE" || {
    echo -e "${RED}Trivy found CRITICAL/HIGH CVEs. Fix before pushing.${NC}"
    read -p "  Continue anyway? (y/N) " yn
    [[ "$yn" == "y" || "$yn" == "Y" ]] || exit 1
}
echo -e "${GREEN}✓ Trivy scan passed${NC}"

# ─── Push ─────────────────────────────────────────────────
echo ""
echo -e "${CYAN}  Pushing to Docker Hub...${NC}"
echo -e "${YELLOW}  (You may be prompted for Docker Hub credentials)${NC}"
docker push "$FULL_IMAGE"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Image pushed: $FULL_IMAGE${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo ""
echo "  Next: bash scripts/03-deploy-local.sh $DOCKERHUB_USERNAME"
echo ""
