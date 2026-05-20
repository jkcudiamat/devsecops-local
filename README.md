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
