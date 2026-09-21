# Day 25 practice output — ServiceAccount + RoleBinding

## Role + RoleBinding applied

```bash
kc get role -n deamon-monitoring
# monitoring-pod-reader

kc describe rolebinding monitoring-pod-reader -n deamon-monitoring
```

```
Subjects:
  Kind            Name            Namespace
  ServiceAccount  monitoring-bot  deamon-monitoring
Role:
  Kind:  Role
  Name:  monitoring-pod-reader
```

## Trap — `--as monitoring-bot` impersonates User, not SA

```bash
kc run monitor-pod --image=grafana/grafana:latest --port=3000 \
  -n deamon-monitoring --as monitoring-bot
```

```
Forbidden: User "monitoring-bot" cannot create resource "pods"
```

**Why:** RoleBinding grants **ServiceAccount** `monitoring-bot`, not User. Also Role only allows get/list/watch — no create anyway.

## Correct check

```bash
kc auth can-i list pods \
  --as=system:serviceaccount:deamon-monitoring:monitoring-bot \
  -n deamon-monitoring
# yes

kc auth can-i create pods \
  --as=system:serviceaccount:deamon-monitoring:monitoring-bot \
  -n deamon-monitoring
# no
```

## What this proves

| Check | Result |
|-------|--------|
| SA as RoleBinding subject | ✓ |
| Read pods allowed for SA | ✓ can-i list |
| create Forbidden (verbs + wrong --as) | ✓ |
| Day 23–25 RBAC arc complete | ✓ User → Cluster → SA |
