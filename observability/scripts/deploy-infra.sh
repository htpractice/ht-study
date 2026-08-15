#!/usr/bin/env bash
# Deploy: obs → workload → peering (peering needs both VPC IDs from remote state)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF="${ROOT}/terraform/environments"

copy_tfvars() {
  local dir="$1"
  local example="$2"
  if [[ ! -f "${dir}/${example%.example}" ]]; then
    cp "${dir}/${example}" "${dir}/${example%.example}"
    echo "Created ${dir}/${example%.example} from example — review before apply."
  fi
}

if ! aws s3api head-bucket --bucket "obs-on-eks-tfstate-obs-$(aws sts get-caller-identity --query Account --output text)" 2>/dev/null; then
  echo "==> Phase 0: bootstrap Terraform state buckets"
  bash "${ROOT}/scripts/bootstrap-state.sh"
fi

echo "==> Phase 1: obs EKS cluster (Prometheus, Grafana, Loki, Jaeger, ADOT, Promtail)"
copy_tfvars "${TF}/obs" "obs.tfvars.example"
terraform -chdir="${TF}/obs" init
terraform -chdir="${TF}/obs" apply -var-file=obs.tfvars

echo "==> Phase 2: workload EKS cluster (retail-store + ADOT + Promtail → obs)"
copy_tfvars "${TF}/workload" "workload.tfvars.example"
terraform -chdir="${TF}/workload" init
terraform -chdir="${TF}/workload" apply -var-file=workload.tfvars

echo "==> Phase 3: VPC peering (workload <-> obs) — required for cross-cluster telemetry"
terraform -chdir="${TF}/peering" init
terraform -chdir="${TF}/peering" apply -auto-approve

echo ""
echo "==> Configure kubectl contexts"
terraform -chdir="${TF}/obs" output -raw configure_kubectl | bash
terraform -chdir="${TF}/workload" output -raw configure_kubectl | bash

echo ""
echo "Obs telemetry endpoints (for verification):"
terraform -chdir="${TF}/obs" output telemetry_endpoints

echo ""
echo "Grafana: $(terraform -chdir="${TF}/obs" output -raw grafana_port_forward)"
echo "Retail URL: $(terraform -chdir="${TF}/workload" output -raw retail_store_url)"
