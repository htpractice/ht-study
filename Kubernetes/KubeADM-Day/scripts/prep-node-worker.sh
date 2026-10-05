#!/usr/bin/env bash
# Worker: common prep (1–5) + kubeadm join + optional kubeconfig fix
#
# Usage:
#   export JOIN_CMD='kubeadm join 10.x.x.x:6443 --token ... --discovery-token-ca-cert-hash sha256:...'
#   sudo -E bash prep-node-worker.sh
#
# Optional env:
#   K8S_VERSION=1.35.7-1.1
#   JOIN_CMD=...                   # required — full join command (without sudo)
#   SETUP_KUBECONFIG=false         # set true only if you run kubectl from this worker
#   KUBECONFIG_USER=ubuntu
#   ADMIN_CONF_SRC=/path/admin.conf  # local path to scp'd admin.conf from master

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=prep-node-common.sh
source "${SCRIPT_DIR}/prep-node-common.sh"

KUBECONFIG_USER="${KUBECONFIG_USER:-ubuntu}"
SETUP_KUBECONFIG="${SETUP_KUBECONFIG:-false}"

if [[ -z "${JOIN_CMD:-}" ]]; then
  echo "ERROR: Set JOIN_CMD to the full kubeadm join line from the control plane."
  echo "  On master: kubeadm token create --print-join-command"
  echo "  On worker: export JOIN_CMD='kubeadm join ...' && sudo -E bash prep-node-worker.sh"
  exit 1
fi

echo "==> [worker] Joining cluster"
# shellcheck disable=SC2086
bash -c "${JOIN_CMD}"

if [[ "${SETUP_KUBECONFIG}" == "true" ]]; then
  echo "==> [worker] Setup kubeconfig (optional — prefer kubectl from master/laptop)"
  KUBE_HOME="$(getent passwd "${KUBECONFIG_USER}" | cut -d: -f6)"
  if [[ -n "${ADMIN_CONF_SRC:-}" && -f "${ADMIN_CONF_SRC}" ]]; then
    install -d -o "${KUBECONFIG_USER}" -g "${KUBECONFIG_USER}" "${KUBE_HOME}/.kube"
    install -o "${KUBECONFIG_USER}" -g "${KUBECONFIG_USER}" -m 600 \
      "${ADMIN_CONF_SRC}" "${KUBE_HOME}/.kube/config"
    echo "    kubeconfig installed from ${ADMIN_CONF_SRC}"
  elif [[ -f /etc/kubernetes/admin.conf ]]; then
    install -d -o "${KUBECONFIG_USER}" -g "${KUBECONFIG_USER}" "${KUBE_HOME}/.kube"
    install -o "${KUBECONFIG_USER}" -g "${KUBECONFIG_USER}" -m 600 \
      /etc/kubernetes/admin.conf "${KUBE_HOME}/.kube/config"
  else
    echo "WARN: SETUP_KUBECONFIG=true but no admin.conf — join succeeded."
    echo "      Copy from master: scp ubuntu@<CP>:/etc/kubernetes/admin.conf /tmp/admin.conf"
    echo "      Then: sudo ADMIN_CONF_SRC=/tmp/admin.conf SETUP_KUBECONFIG=true bash -c '... kubeconfig only ...'"
  fi
fi

echo "==> Worker joined. Verify from control plane: kubectl get nodes"
