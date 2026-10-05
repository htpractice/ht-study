#!/usr/bin/env bash
# Shared host prep (steps 1–5) for kubeadm master and worker nodes.
# Sourced by prep-node-master.sh / prep-node-worker.sh, or run directly:
#   sudo bash prep-node-common.sh
#
# Optional env:
#   K8S_VERSION=1.35.7-1.1

set -euo pipefail

K8S_VERSION="${K8S_VERSION:-1.35.7-1.1}"
K8S_MINOR="v$(echo "${K8S_VERSION}" | cut -d. -f1,2)"

echo "==> [1/5] Disable swap"
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1 disabled for kubeadm/' /etc/fstab

echo "==> [2/5] Kernel modules + sysctl (bridge / ip_forward)"
cat <<EOF >/etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

cat <<EOF >/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

echo "==> [3/5] containerd + Kubernetes packages (${K8S_VERSION})"
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release containerd

install -m 0755 -d /etc/apt/keyrings
rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/Release.key" \
  | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
chmod a+r /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/ /" \
  >/etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-mark unhold kubelet kubeadm kubectl 2>/dev/null || true
apt-get install -y \
  kubelet="${K8S_VERSION}" \
  kubeadm="${K8S_VERSION}" \
  kubectl="${K8S_VERSION}" \
  kubernetes-cni \
  runc \
  cri-tools
apt-mark hold kubelet kubeadm kubectl
systemctl enable --now kubelet

echo "==> [4/5] Configure containerd (systemd cgroup)"
mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl daemon-reload
systemctl restart containerd
systemctl enable containerd

echo "==> [5/5] Configure crictl"
mkdir -p /etc/cni/net.d
cat >/etc/crictl.yaml <<EOF
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
EOF

echo "==> Common prep complete (${K8S_VERSION})"
