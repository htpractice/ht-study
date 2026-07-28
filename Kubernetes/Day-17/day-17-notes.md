# Day 17 — Horizontal Pod Autoscaler (HPA)

Automatic **scale out/in** of pod replicas based on metrics — requires **Metrics Server** (Day 16).

---

## 1. Scaling Types

| Type | What changes | Tool |
|------|--------------|------|
| **Horizontal** | Number of pods/nodes | **HPA**, Cluster Autoscaler |
| **Vertical** | CPU/memory per pod | **VPA** (often needs restart) |

**HPA** = built-in, scales Deployment/ReplicaSet/StatefulSet replicas.  
**Cluster Autoscaler** = adds/removes worker nodes when pods can't schedule.  
**KEDA** = event-driven (queues, custom metrics) — beyond CKA basics.

---

## 2. How HPA Calculates Replicas

```text
desiredReplicas = ceil(currentReplicas × currentMetric / desiredMetric)
```

**Example (CPU target 50%):**

| Current avg CPU | Current replicas | Calculation | Result |
|-----------------|------------------|-------------|--------|
| 200m (100% of 200m request) | 2 | ceil(2 × 100/50) | **4** (scale up) |
| 50m (25% of request) | 4 | ceil(4 × 25/50) | **2** (scale down) |

Controller skips scaling if ratio is close to 1.0 (default tolerance ~10%).

**Requires on every pod:** `resources.requests.cpu` (or memory) — HPA uses **requests** as baseline for utilization %.

---

## 3. Why Scale-Up Worked but Scale-Down Didn't (Lab)

This is **normal** — HPA is asymmetric by design.

### Scale-up is fast
- Reacts within ~15–30s once metrics show sustained high CPU
- Load generator (`wget` loop) pushes CPU above 50% target → replicas increase

### Scale-down is slow (common reasons)

| Reason | Detail |
|--------|--------|
| **Stabilization window** | Default **300s (5 min)** before scale-down — prevents flapping |
| **Load still running** | If `wget` loop still hitting the service, CPU stays high → no scale-down |
| **Metrics lag** | Metrics Server resolution ~15s; average across pods drops slowly |
| **minReplicas** | Can't go below `minReplicas: 1` |
| **New pods cooling** | Recently scaled pods included in average; CPU may still look elevated |

### To see scale-down in lab

```bash
# 1. Stop the load generator (Ctrl+C the wget loop)
# 2. Wait 5+ minutes (default scaleDown stabilization)
kc get hpa php-apache -n hpa-vpa -w
kc describe hpa php-apache -n hpa-vpa    # Events show scaling decisions
```

Optional — faster scale-down for testing (add to HPA spec):

```yaml
behavior:
  scaleDown:
    stabilizationWindowSeconds: 60   # default is 300
    policies:
    - type: Percent
      value: 50
      periodSeconds: 60
```

---

## 4. HPA Prerequisites

1. **Metrics Server** running (`kubectl top pods` works)
2. Target Deployment has **resource requests** defined
3. HPA `scaleTargetRef` points to correct Deployment
4. `minReplicas` / `maxReplicas` set

---

## 5. Hands-on Lab

| File | Purpose |
|------|---------|
| `hpa-vpa-ns.yaml` | Namespace `hpa-vpa` |
| `hpa-deploy.yaml` | php-apache Deployment + Service (official HPA example image) |
| `hpa.yml` | HorizontalPodAutoscaler — CPU 50%, min 1, max 10 |

### Apply order

```bash
kc apply -f hpa-vpa-ns.yaml
kc apply -f hpa-deploy.yaml
kc apply -f hpa.yml
kc get hpa -n hpa-vpa -w
```

### Generate load (scale up)

```bash
# Terminal 1 — watch HPA
kc get hpa php-apache -n hpa-vpa -w

# Terminal 2 — load (official k8s docs pattern)
kubectl run -i --tty load-generator --rm --image=busybox:1.28 --restart=Never -n hpa-vpa -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"
```

### Scale down

```bash
# Stop load generator (Ctrl+C), then wait ~5 min
kc get hpa php-apache -n hpa-vpa
kc get deploy php-apache -n hpa-vpa
```

---

## 6. CKA Exam Tips

```bash
# Generate HPA YAML
kc autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10 \
  -n hpa-vpa --dry-run=client -o yaml > hpa.yml

# Inspect
kc get hpa
kc describe hpa php-apache -n hpa-vpa
kc top pods -n hpa-vpa
```

- apiVersion: `autoscaling/v2` (or v2beta2 in older clusters)
- `target.type: Utilization` + `averageUtilization: 50` = 50% of **request**
- HPA needs **requests** on containers — limits alone are not enough

---

## 7. HPA vs VPA vs Cluster Autoscaler

| | HPA | VPA | Cluster Autoscaler |
|---|-----|-----|-------------------|
| Scales | Pod **count** | Pod **size** (CPU/mem) | **Node** count |
| Built-in | Yes | No (addon) | Cloud/self-managed |
| CKA focus | **High** | Awareness | Awareness |

---

## Reference

- [Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [HPA walkthrough](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)
