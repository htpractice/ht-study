# =============================================================================
# HorizontalPodAutoscaler (HPA) — Interview Quick Reference
# =============================================================================
#
# PREREQUISITES:
#   - Metrics Server installed (kc top pods works)
#   - Pod containers MUST have resources.requests.cpu (utilization % = usage/request)
#   - scaleTargetRef → Deployment/ReplicaSet/StatefulSet
#
# REPLICA FORMULA (interview):
#   desiredReplicas = ceil(currentReplicas × currentMetric / targetMetric)
#   Example: 2 replicas @ 100% CPU, target 50% → ceil(2 × 100/50) = 4
#
# CPU TARGET:
#   averageUtilization: 50  →  scale when avg pod CPU > 50% of REQUEST (not limit)
#   php-apache request=200m → scales when avg > 100m
#
# BEHAVIOR (autoscaling/v2 only):
#   stabilizationWindowSeconds — wait before applying scale decision (anti-flap)
#     scaleDown default: 300s (5 min)  |  scaleUp default: 0s (immediate)
#   policies — max change per period:
#     type: Percent | Pods   value: N   periodSeconds: N
#   selectPolicy:
#     Max      — pick policy allowing BIGGEST change (default) ✓
#     Min      — pick most conservative policy
#     Disabled — NO scaling in that direction ✗ (common mistake!)
#
# LAB — scale up:
#   kubectl run load-generator --rm -it --image=busybox:1.28 -n hpa-vpa -- \
#     /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"
#
# LAB — scale down:
#   1. Ctrl+C load generator
#   2. Wait stabilizationWindowSeconds (60s below, not default 300s)
#   kc get hpa php-apache -n hpa-vpa -w
#
# =============================================================================
# End of reference — apply the lab manifest: ../hpa.yaml
# =============================================================================
