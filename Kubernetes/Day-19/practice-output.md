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
