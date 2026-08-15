#!/usr/bin/env bash
# Tear down multicluster EKS lab (reverse order)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF="${ROOT}/terraform/environments"

echo "==> Destroy workload cluster"
if terraform -chdir="${TF}/workload" init >/dev/null 2>&1; then
  terraform -chdir="${TF}/workload" destroy -var-file=workload.tfvars -auto-approve || true
fi

echo "==> Destroy peering"
if terraform -chdir="${TF}/peering" init >/dev/null 2>&1; then
  terraform -chdir="${TF}/peering" destroy -auto-approve || true
fi

echo "==> Destroy obs cluster (~20 min)"
if terraform -chdir="${TF}/obs" init >/dev/null 2>&1; then
  terraform -chdir="${TF}/obs" destroy -var-file=obs.tfvars -auto-approve || true
fi

echo "Done. Verify: aws eks list-clusters --region us-west-2"
