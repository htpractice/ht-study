# Day 1 — kubeadm EC2: Flannel + GitOps + Upgrade + Monitoring

> **Canonical lab setup spec:** [../docs/LAB-SPEC.md](../docs/LAB-SPEC.md)

> **Complete lab documentation (11-hour E2E build):** [../docs/e2e-lab-complete-runbook.md](../docs/e2e-lab-complete-runbook.md)

**Goal:** One lab covering K8s ops, GitOps, upgrade, observability for the 45-min interview round.  
**Day 2:** [eks-day2.md](../../CICD-Day/docs/eks-day2.md) — full EKS + CI/CD.

**Time:** ~4–5 hours total (cluster 1h, GitOps 1h, monitoring 1h, upgrade 1h).

---

## Interview topics covered

| Phase | Topics |
|-------|--------|
| 0–1 | IaC (Terraform EC2), kubeadm, CNI (Flannel) |
| 2 | GitOps (Argo CD), Helm, desired state in git |
| 3 | Prometheus scrape, Grafana, SLO-style metrics |
| 4 | Cluster upgrade 1.35→1.36, drain, PDB, version skew |
| Day 2 | EKS, ECR, GitHub Actions, AWS-native GitOps |

---

## Phase 0 — Terraform + prep (all 4 nodes)

```bash
cd Kubernetes/KubeADM-Day/kubeadm-on-ec2/infra
terraform apply -var-file=terraform.tfvars
terraform output
```

Copy scripts to each node:

```bash
KEY=private_key.pem
for IP in $(terraform output -json worker_public_ips | jq -r '.[]'), $(terraform output -raw control_plane_public_ip); do
  scp -i $KEY ../scripts/reset-node.sh ../scripts/prep-node.sh ubuntu@${IP}:~
done
```

**On every node** (master + worker1/2/3):

```bash
export K8S_VERSION=1.35.7-1.1
sudo bash reset-node.sh
sudo bash prep-node.sh
kubeadm version   # v1.35.7
```

---

## Phase 1 — Flannel cluster (~45 min)

**Control plane only:**

```bash
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address="${PRIVATE_IP}" \
  --kubernetes-version=v1.35.7

mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

**Flannel** (no BGP/BIRD — unlike Calico):

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
kubectl get nodes -w                    # master Ready
kubectl get pods -n kube-flannel -w     # all Running
kubectl get pods -n kube-system         # CoreDNS Running
```

**Join workers** (save join cmd from init, or `kubeadm token create --print-join-command`):

```bash
# on each worker
sudo kubeadm join <CP_PRIVATE_IP>:6443 --token ... --discovery-token-ca-cert-hash sha256:...
```

Verify:

```bash
kubectl get nodes -o wide   # 4 Ready, v1.35.7
```

Remove CP taint if you want workloads on master during lab (optional):

```bash
kubectl taint nodes master node-role.kubernetes.io/control-plane:NoSchedule-
```

---

## Phase 2 — Argo CD + GitOps app (~1 hr)

**Install Argo CD:**

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait -n argocd --for=condition=available deployment/argocd-server --timeout=300s
```

**Access UI** (from laptop via SSH tunnel to master):

```bash
# on laptop
ssh -i private_key.pem -L 8080:localhost:8080 ubuntu@<CP_PUBLIC_IP>
# on master
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open https://localhost:8080 — user `admin`, password:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d; echo
```

**Deploy order-api via GitOps:**

Push `values-kubeadm.yaml` + `application-order-api-kubeadm.yaml` to `cka-2026-study`, then:

```bash
kubectl apply -f Kubernetes/CICD-Day/argocd/application-order-api-kubeadm.yaml
kubectl get applications -n argocd -w
kubectl get pods -n order-api -o wide
```

**Test** (NodePort 30080 on any worker IP):

```bash
curl http://<WORKER_PUBLIC_IP>:30080/health
curl http://<WORKER_PUBLIC_IP>:30080/metrics | head
```

**GitOps demo:** Edit `values-kubeadm.yaml` → bump `replicaCount: 3` or `image.tag: v2` → push → watch Argo sync.

**Interview line:** "Git is source of truth; Argo reconciles drift with selfHeal. Rollback = git revert + sync."

---

## Phase 3 — Monitoring (~1 hr)

**Helm repos** (on master or laptop with kubeconfig):

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace observability
helm install prometheus prometheus-community/prometheus \
  -n observability \
  -f Kubernetes/Logs&Monitoring-Day/manifests/prometheus-values.yaml
```

**Grafana** (included in prometheus chart):

```bash
kubectl port-forward -n observability svc/prometheus-grafana 3000:80
# admin / prom-operator (get password):
kubectl get secret prometheus-grafana -n observability -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

**Verify scrape:** Prometheus UI → Targets → `kubernetes-pods-annotated` → order-api pods UP.

**Optional Loki** (logs):

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack \
  -n observability \
  -f Kubernetes/Logs&Monitoring-Day/manifests/loki-stack-values.yaml
```

**Interview line:** "App exposes `/metrics` with pod annotations; Prometheus SD picks it up. Same pattern at scale with ServiceMonitor + kube-prometheus-stack."

---

## Phase 4 — Upgrade 1.35.7 → 1.36.x (~1 hr)

**Baseline:**

```bash
kubectl create deployment upgrade-test --image=nginx --replicas=3
kubectl apply -f Kubernetes/KubeADM-Day/manifests/sample-pdb.yaml
kubectl get pods -o wide
```

Find target on CP:

```bash
# add v1.36 repo
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key \
  | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
apt-cache madison kubeadm | grep 1.36
export TARGET_DEB=1.36.x-1.1    # pick latest
export TARGET_PATCH=v1.36.x
```

**Control plane:**

```bash
sudo apt-mark unhold kubeadm kubelet kubectl
sudo apt-get install -y kubeadm=${TARGET_DEB}
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply ${TARGET_PATCH}
sudo apt-get install -y kubelet=${TARGET_DEB} kubectl=${TARGET_DEB}
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl daemon-reload && sudo systemctl restart kubelet
kubectl get nodes
```

**Each worker** (drain → upgrade → uncordon):

```bash
kubectl drain worker1 --ignore-daemonsets --delete-emptydir-data
# on worker1:
sudo apt-mark unhold kubeadm kubelet kubectl
sudo apt-get install -y kubeadm=${TARGET_DEB} kubelet=${TARGET_DEB} kubectl=${TARGET_DEB}
sudo kubeadm upgrade node
sudo systemctl restart kubelet
# on CP:
kubectl uncordon worker1
```

Repeat worker2, worker3. Verify order-api + upgrade-test still healthy; Argo stays Synced.

**Interview line:** "One minor at a time; drain respects PDB; static pods recycled by kubeadm upgrade apply; GitOps app survived rolling node upgrade."

---

## Phase 5 — Teardown (save cost)

```bash
cd kubeadm-on-ec2/infra && terraform destroy -var-file=terraform.tfvars
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Node NotReady | `kubectl get pods -n kube-flannel`; CNI not ready |
| Calico leftovers | `reset-node.sh` on **all** nodes before re-init |
| order-api ImagePullBackOff | `docker pull hthaware2508/order-api-lab:v1` or build/push APP |
| Argo OutOfSync | `kubectl patch application order-api -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'` or UI Sync |
| LoadBalancer Pending | Use `values-kubeadm.yaml` (NodePort), not `values.yaml` |
| Upgrade fails skew | All nodes must step through same minor |

---

## Files reference

| File | Purpose |
|------|---------|
| `scripts/reset-node.sh` | Full CNI/kubeadm cleanup |
| `scripts/prep-node.sh` | containerd + k8s 1.35.7 |
| `CICD-Day/argocd/application-order-api-kubeadm.yaml` | GitOps Application |
| `CICD-Day/helm/order-api/values-kubeadm.yaml` | NodePort, prometheus annotations |
| `manifests/sample-pdb.yaml` | PDB during drain drill |
| `Logs&Monitoring-Day/manifests/prometheus-values.yaml` | Prometheus Helm values |
