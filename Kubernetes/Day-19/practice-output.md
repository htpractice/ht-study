# Day 19 practice output — ConfigMap env injection

## Apply

```bash
kc apply -f configmaps-ns.yaml
kc apply -f app-cm.yaml
kc apply -f pod-cm.yaml
# or: kc apply -f .   (after ns exists)
```

```
configmap/app-config created
pod/cm-pod created
```

## Trap — forgot `-n configmaps`

```bash
kc exec -it cm-pod -- bash
# Error from server (NotFound): pods "cm-pod" not found
```

Pod lives in **`configmaps`** namespace, not `default`. Always match namespace on exec/logs/describe.

## Verify env vars

```bash
kc exec -it cm-pod -n configmaps -- printenv | grep -E 'FIRST|LAST'
```

```
FIRST_NAME=harshal
LAST_NAME=thaware
```

```bash
kc exec -it cm-pod -n configmaps -- bash -c 'echo $FIRST_NAME $LAST_NAME'
# harshal thaware
```

## What this proves

| Check | Result |
|-------|--------|
| `configMapKeyRef` maps CM keys → env names | ✓ `first-name` → `FIRST_NAME` |
| Values visible inside container | ✓ harshal / thaware |
| Namespace required on kubectl | ✓ `-n configmaps` |

---

## Secrets lab (added — instructor skipped)

### Apply

```bash
kc apply -f app-secret.yaml
kc apply -f pod-secret-env.yaml
kc apply -f pod-secret-volume.yaml
kc apply -f pod-cm-volume.yaml
```

### Env injection

```bash
kc exec -it secret-env-pod -n configmaps -- printenv | grep DB_
```

```
DB_USER=admin
DB_PASSWORD=s3cr3t
```

### Volume mount

```bash
kc exec -it secret-vol-pod -n configmaps -- cat /etc/db-creds/username /etc/db-creds/password
# admin
# s3cr3t
```

### Decode from API (troubleshooting / interview)

```bash
kc get secret db-creds -n configmaps -o jsonpath='{.data.password}' | base64 -d && echo
# s3cr3t
```

### ConfigMap volume (comparison)

```bash
kc exec -it cm-vol-pod -n configmaps -- cat /etc/app-config/first-name
# harshal
```

## What Secrets lab proves

| Check | Result |
|-------|--------|
| `secretKeyRef` works like `configMapKeyRef` | ✓ |
| API stores base64; `stringData` avoids manual encode | ✓ |
| Volume mount exposes keys as filenames | ✓ `/etc/db-creds/password` |
| `defaultMode: 0400` on secret volume | ✓ read-only for owner |
