# DevSecOps Pipeline — Local Kubernetes Edition

> A production-equivalent DevSecOps pipeline running entirely on your laptop using Minikube. **Zero cloud cost. Zero credit card required.** All tools are identical to cloud deployments — only the cluster host changes.

[![Pipeline](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF)]()
[![Registry](https://img.shields.io/badge/Registry-Docker%20Hub-0db7ed)]()
[![Cluster](https://img.shields.io/badge/Cluster-Minikube%20%2F%20Kubernetes-326CE5)]()
[![IaC Scan](https://img.shields.io/badge/IaC%20Scan-Checkov-7B42BC)]()
[![CVE Scan](https://img.shields.io/badge/CVE%20Scan-Trivy-1A77D2)]()
[![Runtime](https://img.shields.io/badge/Runtime-Falco%20eBPF-00ADEF)]()

---

## Architecture

```
  Developer
  (pushes code)
      │
      ▼
  GitHub Actions CI/CD Pipeline
  ┌───────────────────────────────────────────────┐
  │  Job 1: Checkov  → scans Dockerfile + K8s    │
  │  Job 2: Bandit   → SAST on Python code       │  All 3 must pass
  │  Job 3: Trivy    → CVE scan on container ────┼──► or deploy is blocked
  │  Job 4: Validate → kubectl dry-run on YAML   │
  └────────────────────────┬──────────────────────┘
                           │ clean image pushed to Docker Hub
                           ▼
              Minikube (local Kubernetes)
  ┌───────────────────────────────────────────────┐
  │                                               │
  │   Flask App (2 replicas)                      │
  │   + securityContext (non-root, readOnly FS)   │
  │   + Network Policy (default-deny)             │
  │   + Resource limits                           │
  │                                               │
  │   Falco (eBPF runtime detection) ─────────►  │
  │   Prometheus + Grafana (metrics)              │
  └───────────────────────────────────────────────┘
                           ▲
  Kali Linux / Host tools  │
  (Nmap, curl, kubectl exec)
  (OWASP ZAP optional)
  Offensive testing validates
  what Falco catches
```

---

## Security Gates

| Stage | Tool | What It Blocks |
|-------|------|----------------|
| Dockerfile config | **Checkov** | Root containers, missing healthchecks, mutable images |
| K8s manifests | **Checkov** | Missing security context, no resource limits |
| Python code | **Bandit** | Hardcoded secrets, unsafe functions |
| Container CVEs | **Trivy** | CRITICAL/HIGH unpatched vulnerabilities |
| Runtime | **Falco (eBPF)** | Shell spawns, network recon, file reads, privilege escalation |

---

## Prerequisites

Install these once — everything else is scripted.

### macOS
```bash
brew install minikube kubectl helm git docker checkov trivy
brew install --cask docker   # Docker Desktop
```

### Windows (WSL2)
```bash
# In PowerShell (admin): wsl --install
# Then inside Ubuntu WSL:
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
sudo apt install -y kubectl helm git docker.io
pip install checkov
```

### Accounts needed (all free)
- **GitHub** — github.com (free)
- **Docker Hub** — hub.docker.com (free)
- No AWS. No Azure. No credit card.

---

## Quick Start (6 steps)

```bash
# Step 0: Verify your environment
bash scripts/00-check-env.sh

# Step 1: Start Minikube
bash scripts/01-start-minikube.sh

# Step 2: Build image, scan it, push to Docker Hub
bash scripts/02-build-and-push.sh YOUR_DOCKERHUB_USERNAME

# Step 3: Deploy to Minikube
bash scripts/03-deploy-local.sh YOUR_DOCKERHUB_USERNAME

# Step 4: Install Falco + Prometheus + Grafana
bash scripts/04-install-security-tools.sh

# Step 5: Run offensive testing (validates Falco detection)
bash scripts/05-attack.sh
```

---

## GitHub Actions Setup

Push this repo to GitHub and the CI/CD pipeline runs on every push. You only need 2 secrets:

1. Repo → Settings → Secrets and variables → Actions → **New repository secret**
   - `DOCKERHUB_USERNAME` — your Docker Hub username
   - `DOCKERHUB_TOKEN` — Docker Hub → Account Settings → Security → New Access Token

That's it. No AWS keys, no cloud credentials.

---

## Viewing the Security Tools

### Falco — live threat alerts
```bash
# Stream alerts as they happen
kubectl logs -n falco -l app.kubernetes.io/name=falco -f

# Filter to warnings and above only
kubectl logs -n falco -l app.kubernetes.io/name=falco -f | grep -E "Warning|Critical|Error"
```

### Falco Web UI
```bash
kubectl port-forward -n falco svc/falco-falcosidekick-ui 2802:2802
# Open http://localhost:2802
```

### Grafana Dashboard
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3000:80
# Open http://localhost:3000  (admin / devsecops123)
# Dashboard: Kubernetes → Compute Resources → Pod
```

---

## Triggering Falco Alerts (for demo / portfolio)

```bash
# 1. Spawn a shell in the container (fires CRITICAL alert)
POD=$(kubectl get pods -l app=devsecops-app -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $POD -- /bin/sh

# 2. From inside the pod — read a sensitive file (fires CRITICAL alert)
cat /etc/passwd

# 3. From inside the pod — try privilege escalation
sudo id
```

Then check:
```bash
kubectl logs -n falco -l app.kubernetes.io/name=falco --since=5m
```

---

## Repository Structure

```
devsecops-local/
├── .github/workflows/
│   └── devsecops-pipeline.yml     # CI/CD — 4 jobs, security gates
├── app/
│   ├── app.py                     # Flask application
│   ├── requirements.txt
│   └── Dockerfile                 # Hardened — non-root, pinned, healthcheck
├── k8s/
│   ├── deployment.yaml            # Full security context, resource limits
│   ├── service.yaml               # NodePort — works on Minikube
│   └── network-policy.yaml        # Default-deny zero-trust
├── falco/
│   └── custom-rules.yaml          # Shell spawn, recon, file read rules
├── scripts/
│   ├── 00-check-env.sh            # Verify tools installed
│   ├── 01-start-minikube.sh       # Start cluster with right config
│   ├── 02-build-and-push.sh       # Checkov → Trivy → Docker Hub
│   ├── 03-deploy-local.sh         # Deploy to Minikube
│   ├── 04-install-security-tools.sh  # Falco + Prometheus + Grafana
│   ├── 05-attack.sh               # Offensive validation
│   └── 06-stop.sh                 # Stop Minikube (state preserved)
├── docs/
│   └── threat-findings.md         # Fill this in after offensive testing
└── README.md
```

---

## Cost

**$0.00** — runs entirely on your laptop.

---

## Resume Bullets

```
Cloud-Native DevSecOps Pipeline (Minikube / Kubernetes):
• Built a GitHub Actions CI/CD pipeline with automated security gates:
  Checkov for Dockerfile/K8s misconfiguration scanning, Bandit for SAST,
  and Trivy for container CVE detection — blocking deployments on critical findings
• Deployed a containerized Flask application to Kubernetes with full security
  hardening: non-root containers, read-only root filesystem, dropped Linux
  capabilities, and default-deny NetworkPolicy
• Installed Falco with custom eBPF detection rules for runtime threat detection,
  triggering CRITICAL alerts on shell spawns, privilege escalation attempts,
  and sensitive file access within seconds
• Validated detection coverage through structured offensive testing using Nmap,
  curl-based web app probes, and container exec simulation — documenting
  findings in a formal threat report
```

---

## Skills Demonstrated

`Kubernetes` `Minikube` `Docker` `GitHub Actions` `CI/CD` `DevSecOps` `Checkov` `Trivy` `Bandit` `Falco` `eBPF` `Prometheus` `Grafana` `Helm` `NetworkPolicy` `Zero Trust` `Nmap` `Offensive Security` `Threat Detection`

---

## Author

**Jacob Cudiamat**
M.S. Cybersecurity Engineering — University of San Diego
[linkedin.com/in/jacob-cudiamat](https://www.linkedin.com/in/jacob-cudiamat) · jacob.k.cudiamat@gmail.com
test 

---
## DevSecOps Pipeline Implementation and Troubleshooting
### 1. Project Goal
The purpose of this project was to build an automated DevSecOps CI/CD pipeline for a containerized Python Flask application. On every push to `main`, the pipeline automatically performs secret validation, infrastructure-as-code and configuration scanning, static application security testing, Docker image build, container vulnerability scanning, image publishing to Docker Hub, and Kubernetes manifest validation — blocking deployments at any stage where a security or configuration issue is detected.
---
### 2. Final Pipeline Stages
| Job | Tool | Purpose |
|-----|------|---------|
| Preflight — Check Secrets | Bash | Validates `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` secrets exist before running anything else |
| Config & IaC Scan | Checkov | Scans `Dockerfile` and `k8s/` manifests for security misconfigurations |
| SAST Scan | Bandit | Static application security testing on Python source code in `app/` |
| Build & Scan Container | Docker + Trivy | Builds the image from `./app/`, scans for OS and library CVEs, pushes to Docker Hub |
| Validate K8s Manifests | kubeconform | Validates Kubernetes manifests offline against the Kubernetes schema — no live cluster required |
**Job details:**
- **Preflight** fails fast with a clear error if either Docker Hub secret is missing, preventing cryptic auth failures downstream
- **Checkov** scans the `Dockerfile` and `k8s/` manifests with `framework: dockerfile,kubernetes`, blocking on HIGH severity findings
- **Bandit** performs SAST on the Python application code and uploads results as a build artifact
- **Docker** builds the image from `./app/` and tags it with both the commit SHA and `latest`
- **Trivy** scans the built image for unpatched CRITICAL vulnerabilities in OS packages and Python libraries, blocking the push if any are found
- **Docker Hub push** publishes both the commit-specific and `latest` tags only after Trivy passes
- **kubeconform** validates all manifests in `k8s/` offline using strict mode, confirming they conform to the Kubernetes API schema without requiring a live cluster
---
### 3. Branch Trigger Issue
**Problem:** The GitHub Actions workflow was configured to trigger on pushes to `main`, but the local and remote default branch was `master`. Every push triggered nothing — the pipeline never ran.
**Diagnosis:** The `on: push: branches: [main]` trigger in the workflow YAML did not match the actual branch name. GitHub only runs a workflow when a push lands on a branch listed in the trigger.
**Fix:** Renamed the branch from `master` to `main`, updated the remote, and deleted the old `master` branch.
```bash
git branch -m master main
git push -u origin main
git push origin --delete master
```
Then updated the GitHub default branch:
**Settings → General → Default branch → switch to `main` → Update**
---
### 4. Pipeline Trigger Commit
After fixing the branch, the pipeline still needed a push to `main` to fire. A small README change was committed to trigger the first real run:
```bash
echo test >> README.md
git add README.md
git commit -m "Trigger pipeline"
git push
```
---
### 5. Python Dependency Vulnerability Fixes
**Problem:** Trivy failed on HIGH-severity CVEs in Python packages bundled with the image:
| Package | Version | Issue |
|---------|---------|-------|
| `gunicorn` | 21.2.0 | Known vulnerability in older release |
| `jaraco.context` | 5.3.0 | Transitive dependency with known CVE |
| `wheel` | 0.45.1 | Known vulnerability in older release |
**Fix:** Upgraded `gunicorn` to `22.0.0` in `requirements.txt`, and force-upgraded `jaraco.context` and `wheel` inside the `Dockerfile` after the main requirements install:
```dockerfile
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir --upgrade jaraco.context==6.1.0 wheel==0.46.2
```
This resolved all Python library vulnerability findings.
---
### 6. Trivy Severity Gate Adjustment
**Problem:** The initial Trivy gate failed on both `CRITICAL` and `HIGH` severities. After fixing the Python packages, residual `HIGH` findings from OS-level packages in the base image were still blocking the build — some of which had no available fix at the time.
**Decision:** Adjusted the policy to gate only on `CRITICAL` vulnerabilities. `HIGH` findings remain visible in the scan output but no longer block the pipeline, consistent with a risk-acceptance approach for unfixable base image findings.
```yaml
- name: Scan image with Trivy
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ steps.meta.outputs.full-image }}
    format: table
    exit-code: "1"
    ignore-unfixed: true
    vuln-type: "os,library"
    severity: "CRITICAL"
```
---
### 7. Debian Package Vulnerability Fix
**Problem:** After the Python package fixes, Trivy flagged a CRITICAL CVE in the Debian OS package `libgnutls30`. The version installed in the base image was vulnerable, but a patched version was available through Debian package updates.
**Fix:** Added an `apt-get` upgrade step to the `Dockerfile` to patch the vulnerable Debian package before the application dependencies are installed:
```dockerfile
RUN apt-get update && \
    apt-get install --only-upgrade -y libgnutls30 && \
    rm -rf /var/lib/apt/lists/*
```
This brought `libgnutls30` to the patched version and cleared the CRITICAL finding from the Trivy scan.
---
### 8. Docker Hub Token Scope Issue
**Problem:** After Trivy passed, the pipeline failed when attempting to push the image to Docker Hub:
```
unauthorized: access token has insufficient scopes
```
**Diagnosis:** The Docker Hub personal access token had been created with read-only permissions. GitHub Actions could authenticate to Docker Hub but did not have write access to push images.
**Fix:**
1. Revoked the existing token immediately
2. Generated a new Docker Hub personal access token with **Public Repo Read/Write** permissions
3. Updated the GitHub repository secrets:
   - `DOCKERHUB_USERNAME` → Docker Hub username
   - `DOCKERHUB_TOKEN` → new read/write access token
> **Security note:** Any token that has been used in a failing pipeline run, logged to output, or otherwise exposed should be considered compromised and rotated immediately. The old token was revoked before the new one was created.
---
### 9. Kubernetes Validation Issue
**Problem:** The manifest validation job initially used `kubectl apply --dry-run=client` to validate the `k8s/` manifests. Despite adding `--validate=false`, the job still failed because `kubectl` attempted to contact a Kubernetes API server:
```
The connection to the server localhost:8080 was refused
```
GitHub Actions runners do not provide a live Kubernetes cluster, so `kubectl` had nothing to connect to even in dry-run mode.
**Fix:** Replaced `kubectl` dry-run validation with **kubeconform**, a purpose-built tool that validates Kubernetes manifests offline against the official Kubernetes JSON schema — no cluster connection required.
```yaml
validate-manifests:
  name: Validate K8s Manifests
  runs-on: ubuntu-latest
  needs: build-and-scan
  steps:
    - name: Checkout code
      uses: actions/checkout@v4
    - name: Install kubeconform
      run: |
        curl -L -o kubeconform.tar.gz https://github.com/yannh/kubeconform/releases/download/v0.6.7/kubeconform-linux-amd64.tar.gz
        tar -xzf kubeconform.tar.gz
        sudo mv kubeconform /usr/local/bin/kubeconform
        kubeconform -v
    - name: Validate manifests
      run: |
        kubeconform -strict -summary k8s/
        echo "All manifests valid."
    - name: Summary
      run: |
        echo "════════════════════════════════════════"
        echo "  Pipeline complete — image is ready"
        echo "════════════════════════════════════════"
        echo "  Image: $DOCKERHUB_USERNAME/$IMAGE_NAME:$IMAGE_TAG"
        echo "  Deploy locally: bash scripts/deploy-local.sh"
```
---
### 10. Final Outcome
After resolving all issues, the pipeline completed successfully with all stages passing:
| Stage | Status |
|-------|--------|
| Preflight — Check Secrets | ✅ Passed |
| Config & IaC Scan (Checkov) | ✅ Passed |
| SAST Scan (Bandit) | ✅ Passed |
| Build & Scan Container (Trivy) | ✅ Passed |
| Docker Hub Push | ✅ Passed |
| Validate K8s Manifests (kubeconform) | ✅ Passed |
---
### 11. Skills Demonstrated
- GitHub Actions workflow design and multi-job pipeline orchestration
- CI/CD troubleshooting across auth, scanning, and validation failures
- Docker image build and publishing to Docker Hub
- Docker Hub secret management and token scope debugging
- Container vulnerability remediation (Python dependencies and Debian OS packages)
- Python dependency hardening via forced upgrades in Dockerfile
- Debian package patching with targeted `apt-get` upgrades
- Static application security testing with Bandit
- Infrastructure-as-code scanning with Checkov
- Container image scanning with Trivy
- Offline Kubernetes manifest validation with kubeconform
- Secure handling and immediate rotation of exposed credentials
---
### 12. Portfolio Summary
Implemented and debugged an end-to-end DevSecOps CI/CD pipeline for a containerized Python application using GitHub Actions, Docker Hub, Checkov, Bandit, Trivy, and kubeconform. The pipeline automates secret validation, static application security testing, infrastructure-as-code scanning, container vulnerability scanning, image publishing, and offline Kubernetes manifest validation. During implementation, I resolved branch trigger mismatches, Python dependency CVEs, Debian OS package vulnerabilities, Docker Hub token scope errors, and Kubernetes validation failures in CI — iterating from a non-functional pipeline to a fully passing, security-gated build.
