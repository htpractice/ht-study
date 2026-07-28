# Day 16 practice output — kc describe pod limit-pod -n resourcelimits
# After applying limit-pod.yaml with stress exceeding memory limit (250Mi > 150Mi limit)

## Key findings

| Field | Value | Meaning |
|-------|-------|---------|
| **Status** | CrashLoopBackOff | Container keeps failing and restarting |
| **Last State** | Terminated, Exit Code 1 | stress/OOM — cannot allocate 250Mi within 150Mi limit |
| **Limits** | cpu 500m, memory 150Mi | Hard caps enforced by kubelet |
| **Requests** | cpu 250m, memory 50Mi | What scheduler reserved on the node |
| **QoS Class** | Burstable | requests ≠ limits |

## Stress args vs limits (why it failed)

```text
stress --vm-bytes 250Mi   >   limits.memory 150Mi   → killed
stress --cpu 1            >   limits.cpu 500m       → throttled (not the crash cause)
```

## Full describe output

```
Name:             limit-pod
Namespace:        resourcelimits
Node:             cka-cluster01-worker2/172.20.0.4
Status:           Running
Containers:
  stress:
    Args:
      --cpu 1
      --vm-bytes 250Mi
      --vm-hang 1
    State:          Waiting
      Reason:       CrashLoopBackOff
    Last State:     Terminated
      Reason:       Error
      Exit Code:    1
    Limits:
      cpu:     500m
      memory:  150Mi
    Requests:
      cpu:        250m
      memory:     50Mi
QoS Class:                   Burstable
Events:
  Warning  BackOff  spec.containers{stress}: Back-off restarting failed container
```

## Fix options

1. Raise limit: `limits.memory: 300Mi` (above stress allocation)
2. Lower stress: `--vm-bytes 100Mi` (below limit)
3. Both demonstrate that limits are enforced — not bypassed by the stress command
