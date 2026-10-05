# kubeadm — Control Plane (Master) Setup

Hands-on notes from EC2 lab. Kubernetes **v1.35.7**, CNI: **Flannel** (`--pod-network-cidr=10.244.0.0/16`).

Use with Terraform outputs from `kubeadm-on-ec2/dev/` or `prod/`.

---

## Example Terraform outputs

```hcl
control_plane_public_ip = "44.242.203.115"
kubeadm_control_plane_sg_id = "sg-0ecf314e19cac2c57"
kubeadm_worker_node_sg_id = "sg-05736d6da07a64bdd"
ssh_control_plane = "ssh -i ./private_key.pem ubuntu@44.242.203.115"
ssh_workers = {
  "w1" = "ssh -i ./private_key.pem ubuntu@34.221.149.228"
  "w2" = "ssh -i ./private_key.pem ubuntu@16.148.125.67"
  "w3" = "ssh -i ./private_key.pem ubuntu@35.90.91.179"
}
worker_public_ips = {
  "w1" = "34.221.149.228"
  "w2" = "16.148.125.67"
  "w3" = "35.90.91.179"
}
```

---

## 1 — Disable swap

```bash
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

---

## 2 — IPv4 forwarding and bridged traffic for iptables

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```

Verify:

```bash
lsmod | grep br_netfilter
lsmod | grep overlay
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
```

---

## 3 — CNI plugins (bridge network for pods)

Static pods (apiserver, scheduler, controller, etcd) run on host network. Pod-to-pod networking needs plugins in `/opt/cni/bin`.

```bash
curl -LO https://github.com/containernetworking/plugins/releases/download/v1.9.1/cni-plugins-linux-amd64-v1.9.1.tgz
sudo mkdir -p /opt/cni/bin
sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.9.1.tgz
```

Alternative (apt from pkgs.k8s.io):

```bash
sudo apt-get install -y kubernetes-cni
```

---

## 4 — Install kubeadm, kubelet, kubectl (v1.35.7)

```bash
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key \
  | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-cache madison kubeadm | grep 1.35

export K8S_VERSION=1.35.7-1.1
sudo apt-mark unhold kubelet kubeadm kubectl 2>/dev/null || true
sudo apt-get install -y \
  kubelet="${K8S_VERSION}" \
  kubeadm="${K8S_VERSION}" \
  kubectl="${K8S_VERSION}" \
  kubernetes-cni \
  runc

sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet
```

---

## 5 — Install and configure containerd

```bash
sudo apt-get install -y containerd

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
sudo systemctl status containerd
```

References:

- containerd runtime: https://github.com/containerd/containerd/releases
- containerd unit file: https://raw.githubusercontent.com/containerd/containerd/main/containerd.service

---

## 6 — Install and configure crictl

```bash
sudo apt-get install -y cri-tools
sudo crictl config runtime-endpoint unix:///var/run/containerd/containerd.sock
```

---

## 7 — kubeadm init

Use the node **private IP** for `--apiserver-advertise-address`.

```bash
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address="${PRIVATE_IP}" \
  --kubernetes-version=v1.35.7
```

Save the `kubeadm join ...` output for workers.

---

## 8 — kubeconfig (control plane)

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Or as root:

```bash
export KUBECONFIG=/etc/kubernetes/admin.conf
```

Copy to laptop (fix server URL to public IP if needed):

```bash
scp -i private_key.pem ubuntu@<CP_PUBLIC_IP>:~/.kube/config ~/.kube/config-kubeadm-app
```

---

## 9 — Install overlay CNI (Flannel)

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
kubectl get nodes -w
kubectl get pods -n kube-flannel -w
kubectl get pods -n kube-system
```

Other CNI options: Calico, Cilium (Calico uses BIRD/BGP — heavier for lab).

---

## 10 — Join command for workers

Workers join using control plane **private IP**:

```bash
sudo kubeadm join 10.100.100.166:6443 --token 5ixcbf.fwlljj5v3c3uvxmv \
  --discovery-token-ca-cert-hash sha256:d9d9a7fddb4f6bcee1a3568d3ec8e6b3386b69754710c1c33263f6550a95c95a
```

Token expires in 24h. Regenerate on master:

```bash
kubeadm token create --print-join-command
```

---

## Runtime stack checklist

For nodes to run pods you need:

| Component | Notes |
|-----------|--------|
| **containerd** | Runtime daemon, systemd enabled |
| **runc** | OCI runtime (`apt-get install runc`) |
| **CNI plugins** | `/opt/cni/bin` or `kubernetes-cni` package |
| **Overlay CNI** | Flannel/Calico after `kubeadm init` |

---

## Troubleshooting notes

### kubectl fails after CNI plugin install

If nodes stay NotReady, confirm Flannel is applied and pod CIDR matches init flag.

On EC2, if pod networking still fails, try disabling **source/destination check** on worker ENIs (AWS console or CLI) — sometimes needed for overlay routing in VPC.

### localhost:8080 connection refused

Same as worker doc — no kubeconfig configured. Complete step 8 above.

---

## Related

- Worker setup: [kubeadm-worker-setup.md](kubeadm-worker-setup.md)
- Automation: `../scripts/prep-node-master.sh` (common steps 1–5 + init + Flannel)
- Full reset: `../scripts/reset-node.sh`
