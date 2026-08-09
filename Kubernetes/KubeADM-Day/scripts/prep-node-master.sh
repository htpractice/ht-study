#!/usr/bin/env bash
# Control plane: common prep (1–5) + CNI check + kubeadm init + Flannel + kubeconfig
#
# Usage:
#   sudo bash prep-node-master.sh
#
# Optional env:
#   K8S_VERSION=1.35.7-1.1
#   K8S_PATCH=v1.35.7              # kubeadm init --kubernetes-version
#   POD_NETWORK_CIDR=10.244.0.0/16   # Flannel default
#   FLANNEL_URL=...                # override Flannel manifest
#   KUBECONFIG_USER=ubuntu         # non-root user for ~/.kube/config
#   INSTALL_CNI_TARBALL=false      # set true to also install containernetworking/plugins tarball
#   CNI_PLUGINS_VERSION=v1.9.1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=prep-node-common.sh
source "${SCRIPT_DIR}/prep-node-common.sh"

K8S_PATCH="${K8S_PATCH:-v1.35.7}"
POD_NETWORK_CIDR="${POD_NETWORK_CIDR:-10.244.0.0/16}"
FLANNEL_URL="${FLANNEL_URL:-https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml}"
KUBECONFIG_USER="${KUBECONFIG_USER:-ubuntu}"
INSTALL_CNI_TARBALL="${INSTALL_CNI_TARBALL:-false}"
CNI_PLUGINS_VERSION="${CNI_PLUGINS_VERSION:-v1.9.1}"

if [[ "${INSTALL_CNI_TARBALL}" == "true" ]]; then
  echo "==> [master] Install CNI plugins tarball (${CNI_PLUGINS_VERSION})"
  tmpdir="$(mktemp -d)"
  curl -fsSL -o "${tmpdir}/cni.tgz" \
    "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-amd64-${CNI_PLUGINS_VERSION}.tgz"
  tar Cxzvf /opt/cni/bin "${tmpdir}/cni.tgz"
  rm -rf "${tmpdir}"
fi

if [[ ! -f /opt/cni/bin/loopback ]]; then
  echo "ERROR: /opt/cni/bin missing plugins — kubernetes-cni package should have installed them."
  exit 1
fi

echo "==> [master] kubeadm init (pod CIDR ${POD_NETWORK_CIDR})"
PRIVATE_IP="$(curl -sf http://169.254.169.254/latest/meta-data/local-ipv4)"
echo "    apiserver-advertise-address=${PRIVATE_IP}"

kubeadm init \
  --pod-network-cidr="${POD_NETWORK_CIDR}" \
  --apiserver-advertise-address="${PRIVATE_IP}" \
  --kubernetes-version="${K8S_PATCH}"

echo "==> [master] kubeconfig for user ${KUBECONFIG_USER}"
KUBE_HOME="$(getent passwd "${KUBECONFIG_USER}" | cut -d: -f6)"
install -d -o "${KUBECONFIG_USER}" -g "${KUBECONFIG_USER}" "${KUBE_HOME}/.kube"
install -o "${KUBECONFIG_USER}" -g "${KUBECONFIG_USER}" -m 600 \
  /etc/kubernetes/admin.conf "${KUBE_HOME}/.kube/config"

echo "==> [master] Install Flannel CNI"
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl apply -f "${FLANNEL_URL}"

echo "==> [master] Waiting for node Ready (timeout 5m)"
kubectl wait --for=condition=Ready node/"$(hostname)" --timeout=300s

echo ""
echo "==> Control plane ready. Save this join command for workers:"
kubeadm token create --print-join-command
