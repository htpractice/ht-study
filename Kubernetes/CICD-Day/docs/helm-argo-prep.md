# Helm + Argo CD — study before lab (~90 min)

Read this, then walk your own chart in `helm/order-api/`. Lab runbook: [e2e-day1.md](../../KubeADM-Day/docs/e2e-day1.md).

---

## Part 1 — Helm (45 min)

### Mental model

Helm = **package manager for Kubernetes**. You don't commit raw YAML for every env — you commit a **Chart** (templates + default values) and override with **values files**.

```
values.yaml  ──►  templates/*.yaml  ──►  rendered manifests  ──►  kubectl apply
   (config)         (Go templates)         (plain K8s YAML)
```

### Chart structure (your repo)

```
helm/order-api/
├── Chart.yaml          # chart metadata (name, version)
├── values.yaml         # defaults — kind/EKS generic
├── values-kubeadm.yaml # overrides for kubeadm EC2 (NodePort)
├── values-aws.example.yaml
└── templates/
    ├── namespace.yaml
    ├── deployment.yaml
    └── service.yaml
```

### Key concepts

| Term | Meaning |
|------|---------|
| **Release** | A deployed instance of a chart (`helm install my-release order-api`) |
| **Values** | Config injected into templates (`replicaCount`, `image.tag`) |
| **Template** | YAML with `{{ .Values.foo }}` placeholders |
| **Helm hook** | Pre/post install Job (migrations) — not in this chart |

### Read your deployment template

In `templates/deployment.yaml`:

- `{{ .Values.replicaCount }}` — scale from values, not hardcoded
- `{{ .Values.image.repository }}:{{ .Values.image.tag }}` — CI bumps tag in Git
- `{{- if .Values.prometheus.scrape }}` — conditional annotations
- `{{- toYaml .Values.resources \| nindent 12 }}` — embed a YAML block from values

### Commands to run **without a cluster** (on your laptop)

```bash
cd Kubernetes/CICD-Day/helm/order-api

# See rendered YAML — best learning tool
helm template order-api . -f values-kubeadm.yaml

# Diff two value files
helm template order-api . -f values.yaml > /tmp/default.yaml
helm template order-api . -f values-kubeadm.yaml > /tmp/kubeadm.yaml
diff /tmp/default.yaml /tmp/kubeadm.yaml
# Only Service type/port should differ
```

### Commands **with a cluster** (optional pre-lab on kind)

```bash
helm install order-api . -f values-kubeadm.yaml -n order-api --create-namespace
kubectl get pods -n order-api
helm list -n order-api
helm upgrade order-api . -f values-kubeadm.yaml --set replicaCount=3
helm uninstall order-api -n order-api
```

### Interview one-liners

- "Helm separates **template** from **environment config** — same chart, different values per env."
- "Chart version vs app version: Chart.yaml `version` is packaging; `appVersion` is the app."
- "I use `helm template` in CI to validate renders before Argo syncs."

---

## Part 2 — Argo CD (45 min)

### Mental model

Argo CD = **GitOps controller**. Cluster state must match Git. You don't `kubectl apply` in prod — you **commit**, Argo **reconciles**.

```
Developer ──► git push (values/tag change)
                    │
                    ▼
              Argo CD polls repo
                    │
                    ▼
              helm template + kubectl apply
                    │
                    ▼
              Cluster matches Git
```

### Pull vs push

| Push CD (Jenkins) | GitOps pull (Argo) |
|-------------------|---------------------|
| Pipeline applies to cluster | Argo watches Git, applies itself |
| Credentials in CI | Argo has cluster credentials |
| Drift common | Drift detected + self-heal |

### Application CR (your manifest)

File: `argocd/application-order-api-kubeadm.yaml`

```yaml
spec:
  source:
    repoURL: https://github.com/htpractice/ht-study.git
    targetRevision: cka-2026-study
    path: Kubernetes/CICD-Day/helm/order-api
    helm:
      valueFiles:
        - values-kubeadm.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: order-api
  syncPolicy:
    automated:
      prune: true      # delete resources removed from Git
      selfHeal: true   # revert manual kubectl edits
```

**What each field means:**

| Field | Purpose |
|-------|---------|
| `source.repoURL` | Git repo to watch |
| `source.path` | Path to Helm chart |
| `helm.valueFiles` | Which values file Argo passes to Helm |
| `destination.namespace` | Target namespace |
| `automated.prune` | GC resources deleted from chart |
| `automated.selfHeal` | Fix drift back to Git |

### Argo UI concepts

| Status | Meaning |
|--------|---------|
| **Synced** | Cluster matches Git |
| **OutOfSync** | Git changed or manual edit |
| **Healthy** | Workloads running |
| **Degraded** | Pods failing |

### Sync vs kubectl

```bash
# BAD in GitOps model (creates drift)
kubectl scale deployment order-api -n order-api --replicas=5

# GOOD — edit values-kubeadm.yaml replicaCount: 5, push, Argo syncs
# With selfHeal: true, manual scale gets reverted
```

### Rollback story

1. **Git revert** the commit that bumped `image.tag` → Argo syncs old version (preferred)
2. **Argo History** → Rollback to revision N
3. Avoid `kubectl rollout undo` alone when selfHeal is on

### Interview one-liners

- "Git is the single source of truth; Argo reconciles desired vs live state."
- "CI builds and updates Git; CD is Argo syncing — separation of concerns."
- "selfHeal catches manual kubectl changes; prune removes orphaned resources."
- "Rollback = revert Git or Argo revision, not ssh to prod."

---

## Part 3 — How they fit together (your lab)

```
GitHub repo (ht-study)
  └── helm/order-api/
        ├── values-kubeadm.yaml   ← you edit replicaCount / image.tag
        └── templates/...

Argo Application ──► reads chart + values ──► deploys to kubeadm cluster

Optional CI (.github/workflows/order-api-cicd.yaml):
  build APP → push ECR → commit tag bump → Argo picks it up
```

**Day 1 lab:** Manual Git edit (bump tag or replicas) → watch Argo sync.  
**Day 2 EKS:** Same flow + GitHub Actions automates the tag bump.

---

## Study checklist (tick before lab)

- [ ] Run `helm template` on `order-api` with both values files; understand diff
- [ ] Explain what happens when `image.tag` changes in values
- [ ] Read `application-order-api-kubeadm.yaml` line by line
- [ ] Explain Synced vs OutOfSync vs selfHeal
- [ ] Explain why CI doesn't kubectl apply to prod
- [ ] Skim [interview-story.md](interview-story.md) deployment strategies table

---

## Quick quiz (answer aloud)

1. Where does replica count live — template or values?
2. What does Argo pass to Helm from the Application CR?
3. Someone `kubectl edit`s the Deployment — what happens with selfHeal?
4. How do you roll back a bad image deploy in GitOps?
5. Difference between `values.yaml` and `values-kubeadm.yaml` in your repo?

<details>
<summary>Answers</summary>

1. **values** (`replicaCount` in values-kubeadm.yaml)
2. **Chart path + valueFiles** — Argo runs helm template internally
3. **Argo reverts** to Git state on next reconcile
4. **git revert** tag bump, or Argo UI rollback
5. **kubeadm** uses NodePort 30080; default may use LoadBalancer/ClusterIP

</details>

---

## Optional reading (30 min max)

- Helm: https://helm.sh/docs/chart_template_guide/getting_started/
- Argo CD core concepts: https://argo-cd.readthedocs.io/en/stable/core_concepts/
- Skip deep dives on Helm hooks, Argo App-of-Apps until after lab
