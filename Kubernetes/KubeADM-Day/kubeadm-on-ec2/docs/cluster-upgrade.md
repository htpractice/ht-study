# kubeadm cluster upgrade — hands-on runbook

**Prerequisite:** Cluster running from [kubeadm-setup.md](kubeadm-setup.md) at version **v1.30.x**.

**Rule:** kubeadm upgrades **one minor version** at a time (1.30 → 1.31 OK; 1.30 → 1.32 not in one jump).

**Version skew (interview):** kubelet may be up to **2 minor versions** behind API server; kubeadm must match the target control-plane version during upgrade.

---

## Overview

```
1. Upgrade control plane (kubeadm upgrade plan / apply)
2. Upgrade kubelet + kubectl on control-plane node
3. For each worker: drain → upgrade packages → kubeadm upgrade node → uncordon
4. Verify + deploy test workload
```

---

## Phase 0 — Baseline

From Mac or k8s-cp:

```bash
kubectl get nodes -o wide
kubectl version
kubeadm version   # on node via multipass shell
```

Note current version, e.g. **v1.30.14**.

Deploy a test app if not already running:

```bash
kubectl create deployment upgrade-test --image=nginx --replicas=3
kubectl get pods -o wide
```

---

## Phase 1 — Upgrade control plane

**On k8s-cp VM:**

### 1.1 Find next version

```bash
sudo apt update
sudo apt-cache madison kubeadm | head -10
# Pick next minor, e.g. 1.31.0-1.1 or latest 1.31.x patch
TARGET=1.31.8-1.1   # adjust to what's available
```

### 1.2 Install target kubeadm (don't restart kubelet yet)

```bash
sudo apt-mark unhold kubeadm kubelet kubectl
sudo apt install -y kubeadm=${TARGET}
sudo apt-mark hold kubeadm kubelet kubectl
```

### 1.3 Plan and apply

```bash
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.31.8   # match available patch, no -1.1 suffix here
```

Watch static pods recycle:

```bash
kubectl get pods -n kube-system -w
```

### 1.4 Upgrade kubelet + kubectl on control plane

If CP is also a worker (single-node), **drain first**:

```bash
kubectl drain k8s-cp --ignore-daemonsets --delete-emptydir-data
# If CP hostname differs: kubectl get nodes
```

Install kubelet/kubectl at target version:

```bash
sudo apt install -y kubelet=${TARGET} kubectl=${TARGET}
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

Uncordon if drained:

```bash
kubectl uncordon k8s-cp
```

Verify:

```bash
kubectl get nodes
kubectl version
```

---

## Phase 2 — Upgrade worker (k8s-w1)

**On k8s-w1 VM:**

### 2.1 Drain from control plane

```bash
# From k8s-cp or Mac
kubectl drain k8s-w1 --ignore-daemonsets --delete-emptydir-data
```

Pods reschedule to CP (if CP has taint removed) or wait until worker returns — in 2-node lab, CP may need `NoSchedule` taint removed for scheduling during drain:

```bash
# Check taints
kubectl describe node k8s-cp | grep -i taint
# Default kubeadm CP taint: node-role.kubernetes.io/control-plane:NoSchedule
# For lab only — allow scheduling on CP during worker drain:
kubectl taint nodes k8s-cp node-role.kubernetes.io/control-plane:NoSchedule-
# Re-add after upgrade: kubectl taint nodes k8s-cp node-role.kubernetes.io/control-plane:NoSchedule
```

### 2.2 Upgrade packages on worker

**On k8s-w1:**

```bash
sudo apt-mark unhold kubeadm kubelet kubectl
sudo apt install -y kubeadm=${TARGET} kubelet=${TARGET} kubectl=${TARGET}
sudo kubeadm upgrade node
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

### 2.3 Uncordon

```bash
kubectl uncordon k8s-w1
kubectl get nodes
# Both should show v1.31.x
```

---

## Phase 3 — Post-upgrade validation

```bash
kubectl get nodes -o wide
kubectl get pods -A | grep -v Running   # should be empty or Completed only
kubectl rollout status deployment/upgrade-test
```

**Interview checks you'd mention in prod:**

- API `/version` matches target
- etcd member health
- CoreDNS, CNI pods healthy
- Run smoke tests / synthetic checks
- PDB respected during drain (see [interview-notes.md](interview-notes.md))

---

## Phase 4 — PDB drill (optional, 15 min)

Apply a PDB, then try draining without respecting it:

```bash
kubectl apply -f ../manifests/sample-pdb.yaml
kubectl drain k8s-w1 --ignore-daemonsets --delete-emptydir-data
# Observe blocking if minAvailable not met
```

---

## Rollback (know for interview — rarely done in practice)

- **No automatic kubeadm downgrade** — restore from etcd snapshot / rebuild node
- **Prod approach:** fix-forward or restore backup; test upgrades in staging first
- **Line:** "We validate upgrades in a staging cluster matching prod; rollback is snapshot-based, not kubeadm downgrades."

---

## Cheat sheet — commands only

```bash
# CP
apt install kubeadm=<target>
kubeadm upgrade plan
kubeadm upgrade apply v<X.Y.Z>
apt install kubelet=<target> kubectl=<target>
systemctl restart kubelet

# Worker
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
apt install kubeadm=<target> kubelet=<target> kubectl=<target>
kubeadm upgrade node
systemctl restart kubelet
kubectl uncordon <node>
```

---

## Patch-only upgrade (same minor)

Same flow but `kubeadm upgrade apply` uses next **patch** (1.30.14 → 1.30.15) — lower risk, good for "rolling security patches" story tied to CVE remediation on your resume.
