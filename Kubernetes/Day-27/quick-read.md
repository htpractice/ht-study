# Day 27 — Storage Quick Read

Full notes: [day-27-notes.md](./day-27-notes.md)

---

## Part 1 — Docker (30 sec)

```text
Image layers     → read-only, immutable, cached on rebuild
Container layer  → writable, ephemeral (CoW) — gone on docker rm
Volume / bind    → persists past container delete
```

| | Volume | Bind mount |
|---|--------|------------|
| Owner | Docker (`/var/lib/docker/volumes/`) | You (any host path) |
| Use | DB, persistence | Dev code, host config |
| K8s | PV + PVC | `hostPath` |

**Remember:** `overlay2` = storage driver (layers). Volume driver = named volumes.

```bash
docker volume create app-data
docker run -d -v app-data:/var/lib/mysql mysql:8
docker run -d -v /host/config:/etc/app:ro nginx
```

**Share data:** same `-v volume-name:/path` on multiple containers (sidecar pattern).

---

## Part 2 — Kubernetes (60 sec)

```text
volumes[]       → what storage (emptyDir, PVC, hostPath)
volumeMounts[]  → where in container (mountPath)
PVC → bind → PV → Pod mounts PVC
```

### Lifetime cheat sheet

| Type | Survives container restart? | Survives Pod delete? |
|------|------------------------------|----------------------|
| container FS | yes (same container) | no |
| **emptyDir** | **yes** | **no** |
| **PVC/PV** | yes | **yes** (policy-dependent) |

### Docker → K8s

| Docker | K8s |
|--------|-----|
| Named volume | PV + PVC |
| Bind mount | `hostPath` |
| Ephemeral layer | `emptyDir` |
| `-v` | `volumes` + `volumeMounts` |
| Config files | ConfigMap/Secret volume (Day 19) |

### PV vs PVC

| | PV | PVC |
|---|----|-----|
| Who | Admin / StorageClass | Developer |
| Scope | Cluster | Namespace |
| What | Storage pool | Request (size, accessMode, SC) |

### Access modes

| Mode | Meaning |
|------|---------|
| **RWO** | One node RW (EBS, local) — most common |
| **ROX** | Many nodes RO |
| **RWX** | Many nodes RW (EFS, NFS) |

### Reclaim policy (PVC deleted)

| Policy | Result |
|--------|--------|
| **Retain** | Data kept; PV → Released |
| **Delete** | PV + cloud disk gone |
| Recycle | Deprecated |

### Static vs dynamic

| Static | Dynamic |
|--------|---------|
| Admin creates PV → PVC binds | PVC + StorageClass → PV auto-created |
| Exam: `kubectl create pv` | Production default |

### Minimal Pod + PVC

```yaml
spec:
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: my-pvc
  containers:
  - name: app
    volumeMounts:
    - name: data
      mountPath: /data
```

### CKA commands

```bash
kubectl create pv pv1 --capacity=10Gi --access-modes=ReadWriteOnce \
  --host-path=/mnt/data --storage-class=manual
kubectl create pvc myclaim --storage-class=manual \
  --access-modes=ReadWriteOnce --size=5Gi
kubectl get pv,pvc,sc
kubectl describe pvc myclaim
```

---

## Decision tree (both)

```text
Must data survive workload delete?
  Docker container rm  → volume or bind (prefer named volume)
  K8s Pod delete       → PVC (not emptyDir)

Multi-node K8s?
  NO  → hostPath OK for lab
  YES → PVC + RWO block or RWX shared FS — never hostPath for DB
```

---

## Exam traps (top 6)

1. PVC `storageClassName` must match PV
2. PVC size ≤ PV capacity; access modes must match
3. Defined volume but no `volumeMounts` → writes go to ephemeral FS
4. emptyDir ≠ persistent (dies with Pod)
5. RWO ≠ share across nodes
6. Recycle policy is obsolete

---

## Interview one-liners

- **Docker:** Layers = immutable app; volumes = data that outlives the container.
- **K8s:** PV/PVC splits admin storage from developer requests.
- **hostPath:** Docker bind mount — fine on one node, broken when Pod moves.
- **Why StorageClass:** Dynamic provisioning — no manual PV in cloud.
