### Kubernetes Architecture Notes

This video provides a comprehensive overview of **Kubernetes architecture**, focusing on the components that keep a cluster running smoothly.

#### 1. Core Concepts
* **Nodes:** A node is essentially a *virtual machine* where components, administrative tasks, and workloads are hosted (1:26).
* **Pods:** The **smallest deployable unit** in Kubernetes. A pod encapsulates one or more containers, allowing them to share resources (3:30).

#### 2. Control Plane (Master Node)
The "brain" of the cluster responsible for management and decision-making (1:21).
* **API Server:** The central hub and main entry point. Every request from the client (via *kubectl*) goes through the API server first (6:07).
* **ETCD:** A distributed **key-value data store** that holds all cluster state, configuration, and secrets (8:46). Only the API server interacts with it (12:40).
* **Scheduler:** Monitors the cluster and assigns workloads (pods) to appropriate worker nodes based on resource constraints (e.g., CPU, memory) (6:35).
* **Controller Manager:** Manages various controllers (e.g., node, namespace, deployment controllers) to ensure the current state matches the desired state of the cluster (7:44).

#### 3. Worker Node Components
Where the actual applications run (2:49).
* **Kubelet:** A node-based agent that receives instructions from the API server to manage pods on the local node (14:05).
* **Kube-Proxy:** Manages network rules and enables communication between pods and services within the cluster (15:39).

#### 4. Workflow Example: Creating a Pod
1. The user sends a request via **kubectl** to the **API Server** (16:44).
2. The **API Server** authenticates/validates the request and records it in **ETCD** (17:28, 18:35).
3. The **Scheduler** identifies a suitable node for the pod and informs the **API Server** (19:11).
4. The **API Server** instructs the **Kubelet** on the chosen worker node to create the pod (20:20).
5. The **Kubelet** executes the task and sends the status back to the **API Server** to update **ETCD** (20:45).
6. The final status is confirmed to the user (21:03).