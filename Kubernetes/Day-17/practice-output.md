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

## Captured output — CPU at 0%, replicas still 6

```text
kc get hpa -n hpa-vpa --watch

NAME         REFERENCE               TARGETS        MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   cpu: 85%/50%   1         10        6          47m
php-apache   Deployment/php-apache   cpu: 91%/50%   1         10        6          48m
php-apache   Deployment/php-apache   cpu: 52%/50%   1         10        6          48m
php-apache   Deployment/php-apache   cpu: 49%/50%   1         10        6          48m
php-apache   Deployment/php-apache   cpu: 32%/50%   1         10        6          48m
php-apache   Deployment/php-apache   cpu: 5%/50%    1         10        6          49m
php-apache   Deployment/php-apache   cpu: 0%/50%    1         10        6          49m   ← load stopped
php-apache   Deployment/php-apache   cpu: 0%/50%    1         10        6          53m   ← still 6 replicas
```

CPU hit **0%** but **REPLICAS stayed at 6** — waiting for the 5-minute scaleDown stabilization window. Keep watching; replicas should drop toward 1 after ~5 min.
