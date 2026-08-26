# Day 18 — Liveness, Readiness, and Startup Probes

How Kubernetes **checks container health** and **self-heals** — high-yield for **CKA/CKAD** and interviews.

---

## 1. Three Probe Types

| Probe | Question | On failure |
|-------|----------|------------|
| **liveness** | Is the container alive? | **Restart** the container |
| **readiness** | Is it ready for traffic? | Remove from **Service endpoints** (no restart) |
| **startup** | Has slow boot finished? | Blocks liveness/readiness until success |

**Interview one-liner:** Liveness = restart; readiness = traffic gate; startup = defer other probes during boot.

---

## 2. Same Pod, Two Probes — `liveness-http-pod.yaml`

This manifest runs **both** liveness and readiness against the same endpoint — on purpose, to show different behavior:

```yaml
# liveness-http-pod.yaml — agnhost serves /healthz:8080, then fails after ~10s
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 3    # wait 3s after container start before first check
  periodSeconds: 3          # check every 3 seconds
  failureThreshold: 1       # 1 failure → restart container

readinessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 3    # same start delay
  periodSeconds: 5          # check every 5 seconds (less aggressive than liveness)
```

### Why different `periodSeconds`?

| Probe | periodSeconds | Rationale |
|-------|---------------|-----------|
| **liveness** | **3** | Detect deadlock/hung process faster → restart sooner |
| **readiness** | **5** | Traffic gating doesn't need to be as aggressive; reduces endpoint flapping |

Both use `initialDelaySeconds: 3` so the app has 3 seconds to start before the first check — avoids false failures on boot.

### Timeline when agnhost `/healthz` starts failing (~10s mark)

```text
0s    container starts, agnhost liveness mode begins
3s    both probes start (initialDelaySeconds)
~10s  /healthz begins returning failures
      → readiness fails: pod marked NotReady, removed from Service endpoints
      → liveness fails (failureThreshold: 1): kubelet RESTARTS container
```

**Key lesson:** Same URL, different consequences — readiness **stops traffic**; liveness **restarts the process**.

### Verify readiness vs liveness (optional Service demo)

```bash
# Expose pod so endpoints reflect readiness
kc expose pod liveness-http -n probes --port=8080 --name=liveness-http
kc get endpoints liveness-http -n probes -w   # IP disappears when NotReady
kc get pod liveness-http -n probes            # Running but 0/1 Ready when probe fails
```

When readiness fails: pod stays **Running**, but **no IP in Endpoints** → Service sends zero traffic there.

### Interview Q: "Why not use the same probe for both?"

> They answer different questions. Readiness protects users during boot or partial failure. Liveness recovers from deadlocks. A slow-start app might fail readiness (no traffic) but still be alive (no restart). A hung app might pass readiness briefly but should fail liveness and get restarted.

---

## 3. Three Check Mechanisms

| Type | Use when | Example |
|------|----------|---------|
| **httpGet** | HTTP app with health endpoint | `path: /healthz`, `port: 8080` |
| **tcpSocket** | Port open check (no HTTP) | `port: 8080` |
| **exec** | Custom script/command | `cat /tmp/healthy` exits 0 = healthy |

### Common probe fields (CKA)

| Field | Meaning | Typical value |
|-------|---------|---------------|
| `initialDelaySeconds` | Wait before first probe | 3–15s |
| `periodSeconds` | How often to probe | 5–10s |
| `failureThreshold` | Failures before action | 1–3 |
| `successThreshold` | Successes to mark healthy (readiness) | 1 |
| `timeoutSeconds` | Probe timeout | 1s default |

---

## 4. Hands-on Lab — Three Liveness Patterns

| File | Mechanism | What happens |
|------|-----------|--------------|
| `probes-ns.yaml` | Namespace | Apply first |
| `liveness-http-pod.yaml` | httpGet `/healthz` | agnhost fails after ~10s → **restart loop** |
| `liveness-exec-pod.yaml` | exec `cat /tmp/healthy` | File deleted after 30s → **restart** |
| `liveness-tcp-pod.yaml` | tcpSocket `:8080` | Stays **Running** if port matches |

```bash
kc apply -f probes-ns.yaml
kc apply -f liveness-http-pod.yaml
kc apply -f liveness-exec-pod.yaml
kc apply -f liveness-tcp-pod.yaml
kc get pods -n probes -w
```

---

## 5. Fixes Applied (vs copied YAML)

| Issue | Original | Fixed |
|-------|----------|-------|
| TCP probe wrong port | `tcpSocket port: 3000` | **`8080`** (matches goproxy containerPort) |
| Typo filename | `liveness-coomad-pod.yaml` | `liveness-exec-pod.yaml` |
| Generic names | `hello`, `tcp-pod` | `liveness-http`, `liveness-tcp` |
| No namespace | default | **`probes`** namespace |
| exec probe | trailing space in `cat` | cleaned |

**Internet copy trap:** TCP liveness on wrong port → probe always fails → CrashLoopBackOff even when app is fine.

---

## 6. Troubleshooting

```bash
kc describe pod <name> -n probes     # probe failure events
kc get events -n probes --sort-by='.lastTimestamp'
kc logs <pod> -n probes --previous   # logs from crashed container
```

| Symptom | Likely cause |
|---------|--------------|
| CrashLoopBackOff immediately | Wrong probe port/path; probe fails from start |
| Restarts every ~30s | Exec demo — file removed (expected in lab) |
| Running fine | TCP/HTTP probe matches actual app port |

---

## 7. ECS Parallel

| K8s | ECS |
|-----|-----|
| livenessProbe | container **healthCheck** (restart task) |
| readinessProbe | ALB target group **health check** (stop traffic) |
| httpGet /healthz | HTTP health check path |
| failureThreshold | unhealthy threshold count |

---

## 8. startupProbe — Slow-Boot Apps

Use when boot takes **longer than liveness would tolerate** (default failure window ≈ `failureThreshold × periodSeconds`).

```yaml
startupProbe:
  httpGet:
    path: /healthz
    port: 8080
  failureThreshold: 30    # 30 × periodSeconds grace before liveness applies
  periodSeconds: 10       # → up to ~300s startup window
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  periodSeconds: 10
readinessProbe:
  httpGet:
    path: /healthz
    port: 8080
  periodSeconds: 5
```

**Flow:** startup succeeds once → liveness/readiness take over. Until then, failed startup checks do **not** trigger liveness restarts.

**Interview one-liner:** startupProbe = "don't kill me while I'm still booting."

**Trap:** Heavy JVM/DB apps failing liveness during warm-up — fix with **startupProbe** or higher `initialDelaySeconds`, not by disabling liveness.

---

## 9. CKA Exam Tips

```bash
# Add probe to generated pod
kc run nginx --image=nginx --dry-run=client -o yaml > pod.yaml
# vim: add livenessProbe under container spec

kc explain pod.spec.containers.livenessProbe
```

- Probes go on **container** spec, not pod spec
- `httpGet.port` can be port number or name from `ports` list
- Don't put liveness on wrong port — #1 copy-paste mistake
- **startupProbe** for apps that need >30s boot — prevents liveness killing them early

### Exam traps (quick table)

| Mistake | Symptom |
|---------|---------|
| Probe port ≠ `containerPort` | Immediate CrashLoopBackOff |
| Liveness too aggressive on slow app | Restart loop during boot — use startupProbe |
| Only readiness, no liveness | Hung process stays in endpoints if readiness still passes |
| Probe on pod spec instead of container | YAML rejected or ignored |

---

## 10. Interview Q&A (CKA + SRE rounds)

| Question | Answer |
|----------|--------|
| Liveness vs readiness? | Liveness → kubelet **restart**; readiness → **Endpoints** gate (no restart) |
| Pod Running but not Ready? | Readiness failing — check probe, dependencies, `/ready` vs `/healthz` |
| When tcpSocket vs httpGet? | tcpSocket = port open only; httpGet = HTTP status + path (prefer for apps) |
| What happens on liveness failure? | Container restart; `RESTARTS` count increases; `kubectl logs --previous` |
| How do probes relate to SLOs? | Readiness keeps bad replicas out of traffic → protects availability SLO during partial failure |
| ECS equivalent? | Liveness ≈ container healthCheck; readiness ≈ load balancer target health |

**Platform SRE angle:** Probes are the **first line** of automated recovery (kubelet restarts, traffic shedding). They complement — not replace — Prometheus alerts, synthetic checks, and incident runbooks. Near-zero downtime = readiness gates + rolling updates + PDBs (later days).

---

## Reference

- [Configure Liveness, Readiness, Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
