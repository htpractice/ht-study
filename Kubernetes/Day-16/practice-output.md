# Day 16 practice output — kc describe pod limit-pod -n resourcelimits

## First run (original YAML — missing `--vm 1`)

Used `--vm-bytes 250Mi` and `--cpu 1` but **no `--vm 1`**. Memory workers never started.

| Field | Value | Meaning |
|-------|-------|---------|
| **Status** | CrashLoopBackOff | Container keeps failing and restarting |
| **Last State** | Terminated, **Exit Code 1**, Reason **Error** | stress exited with error — **NOT OOMKilled** |
| **Limits** | cpu 500m, memory 150Mi | Hard caps enforced by kubelet |
| **Requests** | cpu 250m, memory 50Mi | What scheduler reserved on the node |
| **QoS Class** | Burstable | requests ≠ limits |

## Why Error/1 instead of OOMKilled?

```text
stress requires:  --vm 1  +  --vm-bytes 200Mi   → actually allocates memory
original YAML:    --vm-bytes only (no --vm)     → memory never allocated → Exit Code 1
fixed YAML:       --vm 1 --vm-bytes 200Mi       → exceeds 150Mi limit → OOMKilled (137)
```

Re-apply fixed `limit-pod.yaml` and expect:

```text
Last State:  Terminated
Reason:      OOMKilled
Exit Code:   137
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

1. **Add `--vm 1`** before `--vm-bytes` (required for memory stress)
2. Raise limit: `limits.memory: 300Mi` (pod runs successfully)
3. Lower stress: `--vm-bytes 100Mi` (below 150Mi limit — pod stays Running)
