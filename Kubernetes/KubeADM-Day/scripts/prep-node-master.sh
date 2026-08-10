#!/usr/bin/env bash
# Master: common prep + kubeadm init + Flannel + join command
#   sudo bash prep-node-master.sh
#
# Optional: APISERVER_ADVERTISE_ADDRESS=10.x.x.x  POD_NETWORK_CIDR=10.244.0.0/16

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=prep-node-common.sh
source "${SCRIPT_DIR}/prep-node-common.sh"

POD_NETWORK_CIDR="${POD_NETWORK_CIDR:-10.244.0.0/16}"
K8S_PATCH="${K8S_PATCH:-v1.35.7}"
PRIVATE_IP="${APISERVER_ADVERTISE_ADDRESS:-$(hostname -I | awk '{print $1}')}"

echo "==> [master] kubeadm init (apiserver ${PRIVATE_IP}, pod CIDR ${POD_NETWORK_CIDR})"
kubeadm init \
  --pod-network-cidr="${POD_NETWORK_CIDR}" \
  --apiserver-advertise-address="${PRIVATE_IP}" \
  --kubernetes-version="${K8S_PATCH}"

echo "==> [master] kubeconfig for ubuntu"
mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

echo "==> [master] Flannel"
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

echo ""
echo "==> Done. Join workers with:"
kubeadm token create --print-join-command
