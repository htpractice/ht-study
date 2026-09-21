# KubeADM-Day — Agent Instructions

When the user asks to **set up**, **restore**, **debug**, or **guide** the kubeadm E2E lab (dev + obs on AWS):

1. **Read first:** [docs/LAB-SPEC.md](docs/LAB-SPEC.md) — canonical setup spec with phases and gates.
2. **On failure, consult:**
   - [docs/security-groups-runbook.md](docs/security-groups-runbook.md) — VPC peering, SG ports, console vs Terraform
   - [docs/observability-yaml-runbook.md](docs/observability-yaml-runbook.md) — Prometheus v29, Grafana, Loki, Jaeger, Helm
   - [docs/e2e-lab-complete-runbook.md](docs/e2e-lab-complete-runbook.md) — full narrative + AWS snapshot reference
3. **Branch:** `cka-2026-study` in `htpractice/ht-study`.
4. **Do not skip:** VPC peering + cross-VPC SG rules before multicluster observability.
5. **Do not use:** Prometheus federation to dev; use direct scrape via `configure-obs-multicluster.sh`.
6. **Cross-cluster endpoints:** always obs/dev master **private IP** + **NodePort** (30301, 9100, 30100, 30317).

Bootstrap order: Terraform → peering → kubeadm → obs stack → Argo → dev metrics → multicluster prom → dev promtail → verify.
