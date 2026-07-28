# Day 17 lab observation — HPA scaled up but not down (expected behavior)

## What happened

- Load generator (`wget` loop) pushed CPU above 50% target → **replicas increased** ✓
- After stopping load, replicas **did not decrease immediately** — also expected

## Why scale-down didn't happen quickly

| Factor | Default | Lab impact |
|--------|---------|------------|
| **scaleDown stabilization window** | 300 seconds (5 min) | HPA waits before reducing replicas |
| **Load still running** | — | If wget loop active, CPU stays high |
| **Metrics averaging** | 15s resolution | Utilization drops gradually across all pods |
| **minReplicas** | 1 | Can only scale down to 1, never 0 |

## How to observe scale-down

```bash
# 1. Stop load generator (Ctrl+C)
# 2. Wait 5+ minutes
kc get hpa php-apache -n hpa-vpa -w
kc describe hpa php-apache -n hpa-vpa   # check Events for ScaleDown
```

## Takeaway

**HPA scale-up ≠ symmetric scale-down.** Production design — avoids flapping when traffic spikes briefly. Not a misconfiguration in your YAML.
