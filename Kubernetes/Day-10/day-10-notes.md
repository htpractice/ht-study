This video is part 10 of the *CKA 2024 Full Course* and provides an in-depth explanation of **Kubernetes Namespaces**, covering why they are essential for cluster organization and how to manage them.

### **1. Key Concepts**

- **Purpose of Namespaces:** They provide a layer of **isolation** within a cluster, allowing you to separate objects and resources. This helps prevent accidental modifications or deletions across different environments (e.g., *test* vs *prod*) (0:43 - 3:06).
- **Default Namespaces:** Kubernetes comes with pre-built namespaces like `default` (where resources go if not specified), `kube-system` (for control plane components), `kube-public`, and `kube-node-lease` (4:36 - 7:52).
- **Namespace Management:** Create and delete namespaces using either **declarative** (YAML — see `ns.yaml`) or **imperative** commands:
  - `kubectl create namespace demo`
  - `kubectl get namespaces` (or `kubectl get ns`)
  - `kubectl config set-context --current --namespace=demo` — set default namespace for subsequent commands

### **2. Why Use Namespaces per Project**

- **Isolation:** Logical boundary within a single cluster; resources in one namespace do not interfere with another.
- **Reduced Human Error:** Commands target a specific namespace, making it harder to accidentally modify *test* when you meant *prod* (1:43 - 2:20).
- **Access Control:** RBAC can grant permissions per namespace — users/services only get the access they need (2:21 - 2:30).
- **Resource Organization:** Separates control plane components (`kube-system`) from user applications (1:23 - 1:43).

### **3. Hands-on Connectivity Demo (10:23 - 24:45)**

- **Resource Deployment:** A deployment was created in a custom `demo` namespace and another in `default`.
- **IP vs. Hostname:** Pods in different namespaces can reach each other via **IP address** (IPs are cluster-wide). They cannot resolve each other using a simple service hostname alone.
- **DNS Resolution:** Cross-namespace service access requires the **Fully Qualified Domain Name (FQDN)**:
  - `<service-name>.<namespace>.svc.cluster.local`
  - Example: `backend-svc.demo.svc.cluster.local`

### **4. Cross-Namespace Communication Summary**

| Resource | Scope | Cross-namespace access |
|----------|-------|------------------------|
| **Pod IP** | Cluster-wide | Reachable from any namespace via IP |
| **Service name** | Namespace-scoped | Same-namespace only; use FQDN across namespaces |
| **Why FQDN matters** | — | Pod IPs are ephemeral; Services provide stable endpoints via DNS |

- Pod-to-pod or pod-to-service communication via IP works across namespaces.
- Service-to-service communication across namespaces requires FQDN (point 3 above) — this is the standard approach since pod IPs change on crash/redeploy.
- Namespaces remain vital for order, security, and communication boundaries at scale (27:03).
