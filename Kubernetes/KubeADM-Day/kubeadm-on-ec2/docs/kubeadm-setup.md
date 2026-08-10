# kubeadm cluster setup — Mac lab (Multipass)

**Goal:** Real kubeadm cluster (not kind) so you can practice **`kubeadm upgrade`** for the CrowdStrike round.

**Layout:** `docs/` (guides) · `scripts/` (run on Ubuntu VMs)

**Why Multipass:** kubeadm needs Linux nodes. Docker Desktop on Mac cannot host a real multi-node kubeadm cluster. Multipass gives lightweight Ubuntu VMs with minimal fuss.

**kind vs kubeadm:**

| | kind | kubeadm (this lab) |
|--|------|---------------------|
| Upgrade | `kind upgrade node-image` | `kubeadm upgrade plan/apply` |
| Interview | "dev/test clusters" | "prod-like install & upgrade path" |
| Static pods | hidden in container | visible on control-plane VM |

Keep **kind-cka-cluster01** for CKA drills; use **k8s-cp / k8s-w1** for upgrade practice.

---

## Phase 0 — Install Multipass (Mac, one time)

```bash
brew install multipass
multipass version
```

---

## Phase 1 — Create VMs

Two nodes minimum: **1 control-plane + 1 worker**.

```bash
# Control plane — give it RAM; etcd + API server need headroom
multipass launch 24.04 --name k8s-cp --cpus 2 --memory 4G --disk 25G

# Worker
multipass launch 24.04 --name k8s-w1 --cpus 2 --memory 2G --disk 20G

multipass list
```

Note the IPs:

```bash
CP_IP=$(multipass info k8s-cp | awk '/IPv4/{print $2}')
W1_IP=$(multipass info k8s-w1 | awk '/IPv4/{print $2}')
echo "CP=$CP_IP  W1=$W1_IP"
```

---

## Phase 2 — Prep both nodes

Copy the prep script from your Mac into each VM and run it.

From **lab root** (`KubeADM-Day/`):

```bash
cd ht-study/Kubernetes/KubeADM-Day

multipass transfer scripts/prep-node.sh k8s-cp:/home/ubuntu/prep-node.sh
multipass exec k8s-cp -- sudo bash /home/ubuntu/prep-node.sh

multipass transfer scripts/prep-node.sh k8s-w1:/home/ubuntu/prep-node.sh
multipass exec k8s-w1 -- sudo bash /home/ubuntu/prep-node.sh
```

**Pick ONE Kubernetes minor version** for the initial install (example uses **1.30** — adjust if pkgs.k8s.io has newer):

```bash
# On BOTH nodes — set before prep or export inside prep-node.sh
export K8S_VERSION=1.30.14-1.1
```

Check available versions on a node:

```bash
multipass exec k8s-cp -- bash -c 'apt-cache madison kubeadm | head -5'
```

---

## Phase 3 — Initialize control plane

On **k8s-cp only**:

```bash
multipass shell k8s-cp
```

Inside the VM:

```bash
sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --kubernetes-version=v1.30.14

# Regular user kubeconfig
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Save the **`kubeadm join ...`** line from the output — you need it for the worker.

Install **Calico** CNI (matches `--pod-network-cidr=192.168.0.0/16`):

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
```

Wait for control-plane node Ready:

```bash
kubectl get nodes -w
```

---

## Phase 4 — Join worker

On **k8s-w1**:

```bash
multipass shell k8s-w1
```

Paste the join command from Phase 3, e.g.:

```bash
sudo kubeadm join <CP_IP>:6443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

If token expired (24h default):

```bash
# On k8s-cp
kubeadm token create --print-join-command
```

Verify from **k8s-cp**:

```bash
kubectl get nodes
# Both Ready
```

---

## Phase 5 — kubectl from your Mac (optional)

```bash
multipass exec k8s-cp -- cat /home/ubuntu/.kube/config > ~/.kube/config-kubeadm-lab
export KUBECONFIG=~/.kube/config-kubeadm-lab

# Fix server URL: replace 127.0.0.1 with CP VM IP
CP_IP=$(multipass info k8s-cp | awk '/IPv4/{print $2}')
sed -i '' "s/127.0.0.1/${CP_IP}/" ~/.kube/config-kubeadm-lab

kubectl get nodes
```

Switch back to kind anytime:

```bash
kubectl config use-context kind-cka-cluster01
```

---

## Phase 6 — Sanity checks (connects to CKA + interview)

```bash
# Static pods on control plane
kubectl get pods -n kube-system

# On k8s-cp VM
ls /etc/kubernetes/manifests
sudo crictl ps

# Deploy sample app
kubectl create deployment nginx --image=nginx --replicas=2
kubectl get pods -o wide
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `preflight` swap error | Prep script disables swap; reboot if needed |
| Node NotReady | CNI not installed — apply Calico |
| Join fails | Regenerate join command; check firewall between VMs |
| `kubectl` from Mac fails | Fix `server:` IP in kubeconfig |
| Wrong kubeadm version | Same **patch** on all nodes before upgrade practice |

---

## Next

→ [cluster-upgrade.md](cluster-upgrade.md) — upgrade 1.30 → 1.31 (one minor at a time)

→ [interview-notes.md](interview-notes.md) — PDB, drain/cordon, version skew

---

## Teardown

```bash
multipass delete k8s-cp k8s-w1 --purge
rm -f ~/.kube/config-kubeadm-lab
```
