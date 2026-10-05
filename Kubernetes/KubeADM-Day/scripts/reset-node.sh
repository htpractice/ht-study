#!/usr/bin/env bash
# Full kubeadm + CNI cleanup. Run on EVERY node before a fresh init/join.
# Usage: sudo bash reset-node.sh

set -euo pipefail

echo "==> kubeadm reset"
kubeadm reset -f --cri-socket=unix:///var/run/containerd/containerd.sock 2>/dev/null || kubeadm reset -f

echo "==> Remove Kubernetes + CNI state"
rm -rf /etc/kubernetes \
       /var/lib/kubelet \
       /var/lib/etcd \
       /var/lib/cni \
       /etc/cni/net.d \
       "$HOME/.kube"

# Re-install base CNI plugins if apt removed them (kubelet needs /opt/cni/bin)
if ! ls /opt/cni/bin/loopback >/dev/null 2>&1; then
  apt-get update
  apt-get install -y --reinstall kubernetes-cni 2>/dev/null || true
fi

echo "==> Remove stale Calico / tun / bridge interfaces"
ip link delete cni0 2>/dev/null || true
ip link delete tunl0 2>/dev/null || true
ip link delete flannel.1 2>/dev/null || true
while read -r iface; do
  ip link delete "$iface" 2>/dev/null || true
done < <(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(cali|vxlan|cni)' || true)

echo "==> Flush iptables (lab only — do not run on shared hosts)"
iptables -F 2>/dev/null || true
iptables -t nat -F 2>/dev/null || true
iptables -t mangle -F 2>/dev/null || true
iptables -X 2>/dev/null || true
ip6tables -F 2>/dev/null || true
ip6tables -t nat -F 2>/dev/null || true

echo "==> Restart container runtimes"
systemctl restart containerd
systemctl restart kubelet 2>/dev/null || true

echo "==> Done. Re-run prep-node.sh on this node before init/join."
