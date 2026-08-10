# kubeadm — Worker Node Setup

Hands-on notes from EC2 lab. Same host prep as master; workers **join** instead of init.

Kubernetes **v1.35.7** — version must match control plane at join time.

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

## 3 — Install kubeadm, kubelet, kubectl, containerd, runc (v1.35.7)

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
  containerd \
  runc

sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet
```

Also install CNI plugins (same as master):

```bash
sudo apt-get install -y kubernetes-cni
# OR manual tarball — see kubeadm-master-setup.md §3
```

---

## 4 — Configure containerd

```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
sudo systemctl status containerd
```

---

## 5 — Install and configure crictl

```bash
sudo apt-get install -y cri-tools
sudo crictl config runtime-endpoint unix:///var/run/containerd/containerd.sock
```

---

## 6 — Join cluster (requires root)

Get join command from master init output, or on master:

```bash
kubeadm token create --print-join-command
```

On worker — use control plane **private IP**:

```bash
sudo kubeadm join 10.100.100.17:6443 \
  --token eqjig0.eiij6gcv17b8nrn0 \
  --discovery-token-ca-cert-hash sha256:376b4f6776580e78c59bf65b10d92a7711e8517c340f72410a537e390a0e01a9
```

Verify from **master**:

```bash
kubectl get nodes -o wide
```

---

## 7 — kubeconfig (only if running kubectl on this worker)

Workers do not need kubeconfig for join. Only configure if you run `kubectl` from the worker itself:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Or copy `admin.conf` from control plane to this node.

Alternatively, as root:

```bash
export KUBECONFIG=/etc/kubernetes/admin.conf
```

**Normal practice:** run `kubectl` from master or laptop, not from workers.

---

## Troubleshooting

### ERROR: connection to localhost:8080 refused

```
E0809 11:55:44.478530    3305 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"http://localhost:8080/api?timeout=32s\": dial tcp 127.0.0.1:8080: connect: connection refused"
The connection to the server localhost:8080 was refused - did you specify the right host or port?
```

**Cause:** `kubectl` has no config — defaults to `http://localhost:8080`.

**Fix:** Complete step 7 (copy `admin.conf` from control plane), **or** run kubectl from master/laptop instead.

---

## Post-join checks (from master)

```bash
kubectl get nodes
kubectl get pods -n kube-system -o wide
```

Worker should show **Ready** after Flannel is running on the cluster.

Debug runtime on worker without kubectl:

```bash
sudo crictl ps
sudo crictl pods
sudo systemctl status kubelet
sudo journalctl -u kubelet -f
```

---

## Related

- Control plane setup: [kubeadm-master-setup.md](kubeadm-master-setup.md)
- Automation: `../scripts/prep-node-worker.sh` (common steps 1–5 + join)
- Full reset: `../scripts/reset-node.sh`
