#!/usr/bin/env bash
# Copy kubeadm prep scripts to EC2 nodes by role (after terraform apply).
#
# Usage:
#   ./copy-scripts-to-nodes.sh dev
#   ./copy-scripts-to-nodes.sh prod
#   ./copy-scripts-to-nodes.sh obs
#   ./copy-scripts-to-nodes.sh /path/to/kubeadm-on-ec2/dev
#
# Master receives: prep-node-common.sh, prep-node-master.sh, reset-node.sh
# Workers receive: prep-node-common.sh, prep-node-worker.sh, reset-node.sh
#
# Then SSH and run:
#   Master:  sudo bash ~/reset-node.sh && sudo bash ~/prep-node-master.sh
#   Worker:  sudo bash ~/reset-node.sh
#            export JOIN_CMD='kubeadm join ...'
#            sudo -E bash ~/prep-node-worker.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBEADM_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

resolve_tf_dir() {
  case "${1:-}" in
    dev|prod|obs)
      echo "${KUBEADM_ROOT}/kubeadm-on-ec2/${1}"
      ;;
    "")
      echo "Usage: $0 dev|prod|obs|/path/to/terraform/dir" >&2
      exit 1
      ;;
    *)
      echo "$(cd "${1}" && pwd)"
      ;;
  esac
}

TF_DIR="$(resolve_tf_dir "${1:-}")"
KEY="${TF_DIR}/private_key.pem"
SSH_OPTS=(-i "${KEY}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)

MASTER_SCRIPTS=(
  prep-node-common.sh
  prep-node-master.sh
  reset-node.sh
)
WORKER_SCRIPTS=(
  prep-node-common.sh
  prep-node-worker.sh
  reset-node.sh
)

if [[ ! -f "${KEY}" ]]; then
  echo "ERROR: ${KEY} not found. Run terraform apply in ${TF_DIR} first." >&2
  exit 1
fi

chmod 600 "${KEY}"

cd "${TF_DIR}"
CP_IP="$(terraform output -raw control_plane_public_ip)"
WORKER_JSON="$(terraform output -json worker_public_ips)"
ENV="$(terraform output -raw environment 2>/dev/null || echo unknown)"
ROLE="$(terraform output -raw cluster_role 2>/dev/null || echo unknown)"

echo "==> Environment: ${ENV} (${ROLE})"
echo "==> Control plane: ${CP_IP}"

copy_to() {
  local ip="$1"
  shift
  local files=("$@")
  echo "    → ${ip}: ${files[*]}"
  scp "${SSH_OPTS[@]}" "${files[@]}" "ubuntu@${ip}:~/"
  ssh "${SSH_OPTS[@]}" "ubuntu@${ip}" 'chmod +x ~/*.sh'
}

MASTER_PATHS=()
for f in "${MASTER_SCRIPTS[@]}"; do
  MASTER_PATHS+=("${SCRIPT_DIR}/${f}")
done

echo "==> Copy master scripts"
copy_to "${CP_IP}" "${MASTER_PATHS[@]}"

echo "==> Copy worker scripts"
while read -r name ip; do
  [[ -z "${name}" ]] && continue
  WORKER_PATHS=()
  for f in "${WORKER_SCRIPTS[@]}"; do
    WORKER_PATHS+=("${SCRIPT_DIR}/${f}")
  done
  echo "  worker ${name}"
  copy_to "${ip}" "${WORKER_PATHS[@]}"
done < <(echo "${WORKER_JSON}" | jq -r 'to_entries[] | "\(.key) \(.value)"')

echo ""
echo "==> Done. Next steps:"
echo "  Master (${CP_IP}):"
echo "    ssh -i ${KEY} ubuntu@${CP_IP}"
echo "    sudo bash ~/reset-node.sh    # skip if fresh node"
echo "    sudo bash ~/prep-node-master.sh"
echo ""
echo "  Each worker:"
echo "    export JOIN_CMD='kubeadm join <CP_PRIVATE_IP>:6443 --token ... --discovery-token-ca-cert-hash sha256:...'"
echo "    sudo bash ~/reset-node.sh"
echo "    sudo -E bash ~/prep-node-worker.sh"
