# Day 14 lab commands — taints, tolerations, nodeSelector
# Node names (cka-cluster01) — adjust for your cluster: kc get nodes

| Command | Purpose |
|---------|---------|
| `kc run toleration-pod --image=nginx --dry-run=client -o yaml > toleration-pod.yaml` | Generate base pod YAML |
| `kc apply -f toleration-pod.yaml` | Apply pod with toleration |
| `kc get po` | List pods |
| `kc describe po toleration-pod` | Verify toleration and node placement |
| `kc describe no cka-cluster01-worker2` | Inspect node taints/labels |
| `kc taint node cka-cluster01-worker2 gpu=false:NoSchedule-` | Remove taint (trailing dash) |
| `kc taint node cka-cluster01-worker gpu=false:NoSchedule-` | Remove taint from worker |
| `kc taint node cka-cluster01-worker2 gpu=true:NoSchedule` | Add GPU taint to worker2 |
| `kc taint node cka-cluster01-worker gpu=true:NoSchedule` | Add GPU taint to worker |
| `kc apply -f nodeselector-pod.yaml` | Apply nodeSelector pod |
| `kc describe po nodeselector-pod` | Verify nodeSelector scheduling |
| `kc label node cka-cluster01-worker2 gpu=true` | Label node for nodeSelector |
| `kc get no --show-labels` | List nodes with labels |
| `kc get no cka-cluster01-worker2 --show-labels` | Labels on specific node |
| `kc get po -o wide` | Pod placement across nodes |
