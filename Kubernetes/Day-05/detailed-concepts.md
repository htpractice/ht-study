To build on your notes, here is a more detailed look at the core components of a **Kubernetes cluster**. You can think of the **Control Plane** as the "brain" that handles cluster-wide decisions, while **Worker Nodes** act as the "muscle" that executes those decisions.

### 1. Control Plane Components (The Decision Layer)
The Control Plane ensures the cluster's global state matches your desired configuration (e.g., "I want 3 replicas of this pod").

*   **kube-apiserver:** The central gateway. Every command from `kubectl` or internal system components must pass through the API server. It validates and configures data for the API objects, which include pods, services, and replication controllers. It is the *only* component that communicates directly with `etcd`.
*   **etcd:** A consistent and highly-available key-value store used as Kubernetes' backing store for all cluster data. It acts as the "source of truth" for the cluster state. Because it holds critical data, it is often configured with high availability (multiple replicas) in production.
    - **Flexibility in Data Structure:** Unlike relational databases that rely on a fixed schema (rows and columns) where every record must follow the same structure, etcd stores data in a document-like format (often JSON) (10:06 - 11:24).
    - **No Pre-defined Constraints:** In a traditional RDBMS, adding a new field (like an address) to an existing table would require altering the entire table schema to accommodate all records. In contrast, etcd allows for dynamic, varied data structures per entry without requiring prior schema modifications (10:06 - 10:56).
    - **Key-Value Pairs:** It stores information as simple key and value pairs. This allows the cluster to store diverse information—such as pod states, configurations, and secrets—without being forced into a rigid, uniform table format (11:18 - 12:17). 
*   **kube-scheduler:** When you create a new pod, the scheduler watches for unscheduled pods and selects the most appropriate node for them to run on. It considers resource requirements (CPU/Memory), hardware/software constraints, data locality, and affinity/anti-affinity specifications.
*   **kube-controller-manager:** A daemon that embeds the core control loops. It ensures that the current state of the cluster is always moving toward the desired state. Examples include:
    *   **Node Controller:** Keeps track of node health.
    *   **Job Controller:** Watches for Job objects and creates pods to run those tasks.
    *   **Endpoints Controller:** Populates the endpoints object (joining services and pods).

### 2. Worker Node Components (The Execution Layer)
These components run on every node to maintain running pods and provide the necessary runtime environment.

*   **kubelet:** An agent that runs on each node in the cluster. It ensures that containers are running in a **pod** as described by the `PodSpecs` provided by the API server. It does not manage containers not created by Kubernetes; it specifically monitors the health of containers and reports back to the control plane.
*   **kube-proxy:** A network proxy that runs on each node. It maintains network rules on the nodes, allowing communication to your pods from inside or outside the cluster. It handles the abstraction of *Services* by ensuring that traffic directed to a service IP is correctly routed to the appropriate backend pods, often using mechanisms like *iptables* or *IPVS*.

For a visual overview, you can refer to the official [Kubernetes Cluster Architecture documentation](https://kubernetes.io/docs/concepts/architecture/).