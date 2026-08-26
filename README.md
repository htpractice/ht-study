# ht-study

SRE / DevOps / Kubernetes learning repo — hands-on labs, notes, and Terraform.

## Branches

| Branch | Focus | Start here |
|--------|--------|------------|
| **`cka-2026-study`** | CKA / kubeastronaut path — Day notes, kubeadm E2E, GitOps/Helm/Argo | `Kubernetes/` |
| **`obs-on-eks`** | Multicluster observability on EKS — Prometheus, Grafana, Loki, Jaeger, ADOT | [`observability/README.md`](observability/README.md) |
| **`main`** | Early Python / Terraform notes | `Python/`, `Terraform/` |

```bash
git clone https://github.com/htpractice/ht-study.git
cd ht-study
git checkout cka-2026-study   # or obs-on-eks
```

## Local-only (not in git)

These stay on your machine — see [`.gitignore`](.gitignore):

- **`interview-prep/`** — company-specific interview notes
- **`Kubernetes/AEP-local-to-k8s/`** — work-related local notes
- Terraform state, kubeconfigs, keys

## Observability lab (obs-on-eks)

```bash
cd observability
bash scripts/bootstrap-state.sh    # once
bash scripts/deploy-infra.sh
bash scripts/verify-telemetry.sh
bash scripts/destroy-infra.sh      # teardown
```

Docs: [LAB-SPEC](observability/docs/LAB-SPEC.md) · [PRACTICE-ROADMAP](observability/docs/PRACTICE-ROADMAP.md) · [TROUBLESHOOTING-REF](observability/docs/TROUBLESHOOTING-REF.md)
