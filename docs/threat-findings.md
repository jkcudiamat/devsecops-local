# Threat Findings — DevSecOps Local Lab

**Date:** <!-- fill in after running 05-attack.sh -->
**Tester:** Jacob Cudiamat
**Target:** devsecops-app (Minikube)

---

## Summary

| # | Attack | Falco Rule Triggered | Severity | Detected? |
|---|--------|----------------------|----------|-----------|
| 1 | Shell spawn via `kubectl exec` | Shell Spawned in DevSecOps App Container | CRITICAL | |
| 2 | Read `/etc/passwd` from inside pod | Sensitive File Read in Container | CRITICAL | |
| 3 | `sudo id` inside pod | Privilege Escalation Attempt | CRITICAL | |
| 4 | Nmap port scan from host | (network policy blocks inbound) | — | |
| 5 | Path traversal / web probes | (app returns 404 — no vuln exposed) | — | |

---

## Findings

### Finding 1 — Shell Spawn (CRITICAL)

**Attack:**
```bash
kubectl exec -it <pod> -- /bin/sh
```

**Falco alert:**
```
# paste kubectl logs output here
```

**Result:** <!-- Detected / Not detected -->

---

### Finding 2 — Sensitive File Read (CRITICAL)

**Attack:** (from inside pod)
```bash
cat /etc/passwd
```

**Falco alert:**
```
# paste kubectl logs output here
```

**Result:** <!-- Detected / Not detected -->

---

### Finding 3 — Privilege Escalation (CRITICAL)

**Attack:** (from inside pod)
```bash
sudo id
```

**Falco alert:**
```
# paste kubectl logs output here
```

**Result:** <!-- Detected / Not detected -->

---

### Finding 4 — Port Scan (Nmap)

**Attack:**
```bash
nmap -sV -p- <minikube_ip>
```

**Result:** <!-- describe what was visible / blocked by NetworkPolicy -->

---

### Finding 5 — Web Application Probes

**Attack:**
```bash
curl http://<app_url>/../../../etc/passwd
curl http://<app_url>/?id=1'OR'1'='1
curl http://<app_url>/?q=<script>alert(1)</script>
```

**Result:** <!-- describe HTTP responses — all 404s expected -->

---

## Security Headers Analysis

<!-- paste output of: curl -sI http://<app_url>/ -->

Missing headers to add (future improvement):
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Content-Security-Policy`
- `Strict-Transport-Security`

---

## Conclusion

<!-- 2-3 sentences: what the lab demonstrated, what Falco caught, what it missed -->
