# Day 22 practice output — RBAC auth can-i

## Apply lab

```bash
kc apply -f rbac-ns.yaml
kc apply -f sa-pod-reader.yaml
kc apply -f role-pod-reader.yaml
kc apply -f rolebinding-pod-reader.yaml
```

## Verify authorization

```bash
kc auth can-i list pods \
  --as=system:serviceaccount:rbac-lab:pod-reader-sa -n rbac-lab
# yes

kc auth can-i delete pods \
  --as=system:serviceaccount:rbac-lab:pod-reader-sa -n rbac-lab
# no
```

## ECS parallel (mental check)

| ECS | This lab |
|-----|----------|
| IAM policy actions | Role `verbs` |
| Principal (task role) | ServiceAccount `pod-reader-sa` |
| Policy attachment | RoleBinding `read-pods` |

## What this proves

| Check | Result |
|-------|--------|
| Role defines least-privilege verbs | ✓ get/list/watch only |
| RoleBinding links SA → Role | ✓ |
| `auth can-i` tests authz without switching user | ✓ |
| IAM intuition maps to RBAC | ✓ |
