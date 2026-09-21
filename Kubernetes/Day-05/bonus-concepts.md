In Kubernetes, **helper containers**—often referred to as **sidecar containers**—are secondary containers deployed alongside the main application container within the same **Pod**. Because they share the same network namespace and storage volumes as the main container, they can seamlessly extend or enhance its functionality without needing to modify the application code itself.

### Common Roles of Helper/Sidecar Containers:

* **Logging:** They can collect, process, or forward logs from the main application to a centralized logging system (e.g., *Fluentd* or *Logstash*).
* **Monitoring and Observability:** Sidecars often act as agents to export metrics from the application to monitoring tools like *Prometheus*.
* **Security:** They can handle tasks like managing TLS certificates or performing traffic encryption/decryption (common in *Service Mesh* architectures like *Istio*).
* **Configuration Management:** They can sync configuration files or secrets from external sources to ensure the main application always has the latest settings.
* **Proxying:** Sidecars can act as a local proxy (e.g., an *Envoy* proxy) to manage inter-service communication, load balancing, or request retries.

By offloading these auxiliary tasks to a sidecar, you keep the main application container lightweight and focused solely on its primary business logic.

---
The **kube-proxy** component is responsible for creating and maintaining the networking rules on each worker node (15:35 - 16:03). 

Here is how it functions:
* **Network Rule Management:** It maintains essential network rules to ensure communication occurs between different **pods** and **services** across the cluster (15:43 - 15:56).
* **IP Table Rules:** It typically creates and manages *IP table* rules (or sometimes *IPVS* rules) on the node to handle traffic routing correctly (15:52 - 16:03).
* **Enabling Connectivity:** By setting up these rules, *kube-proxy* facilitates the **pod-to-pod** networking required for microservices to interact with each other seamlessly (15:52 - 16:03).

---

In a Kubernetes cluster, **internal networking** on worker nodes is primarily managed by the **kube-proxy** component (15:35 - 16:03). 

Here is how it functions:

* **Network Rule Management:** The *kube-proxy* maintains essential network rules on each worker node. This ensures that communication can occur between different **pods** and **services** across the cluster (15:43 - 15:56).
* **IP Table Rules:** It typically creates and manages *IP table* rules (or sometimes *IPVS* rules) on the node to handle traffic routing correctly. This abstraction is what allows your applications to communicate reliably, even when pods are dynamic and have shifting IP addresses (15:52 - 16:03).
* **Enabling Connectivity:** By setting up these rules, *kube-proxy* essentially facilitates the **pod-to-pod** networking required for microservices to interact with each other seamlessly (15:52 - 16:03).

---

The **API Server** is the component responsible for validating incoming user requests in a Kubernetes cluster (17:15 - 18:24). 

When a user sends a request using the *kubectl* client, the **API Server** performs several critical functions to ensure the request is valid before any action is taken:

* **Authentication:** It verifies the identity of the user making the request to ensure they have the right to interact with the cluster (17:26 - 17:36).
* **Authorization:** It checks if the authenticated user has the necessary permissions to perform the requested operation (17:29 - 17:36).
* **Validation:** It ensures that the request itself is valid and properly formatted according to Kubernetes standards (17:42 - 17:50).

Only after these checks are successfully completed does the **API Server** proceed to interact with other components, such as *etcd* or the *scheduler*, to fulfill the request (18:16 - 18:32).

---

The **Kubelet** is a critical component that acts as a node-based agent responsible for executing instructions within a worker node in a Kubernetes cluster (13:57 - 14:10). 

Its primary roles include:

* **Communication:** It serves as the bridge between the *Control Plane* and the *Worker Node*. It receives instructions directly from the *API Server* regarding what should be running on the node (14:05 - 14:12, 15:17 - 15:33).
* **Workload Management:** When the *API Server* issues a command, such as creating or deleting a *Pod*, the *Kubelet* carries out that action on the local node (14:40 - 15:00).
* **Status Reporting:** After completing a task, the *Kubelet* reports back to the *API Server* to confirm that the requested operation was successful. This ensures the *Control Plane* stays updated on the actual state of the cluster (15:02 - 15:14, 20:45 - 21:00).

---

After the **Kubelet** completes a task (such as scheduling or deleting a *Pod*), it follows a specific communication flow to ensure the cluster state remains consistent:

* **Reporting Back:** The *Kubelet* sends a response back to the **API Server** confirming that the requested action has been successfully executed (15:02 - 15:10, 23:18 - 23:33).
* **State Update:** Once the *API Server* receives this confirmation, it updates the status of the *Pod* or resource within the **etcd** database to reflect the current, accurate state of the cluster (15:11 - 15:14, 20:45 - 21:00).
* **Completion:** With the database now updated, the *API Server* can provide the final status back to the user who initiated the original request (21:03 - 21:09, 23:29 - 23:33).


---
* **High Level Architecture Notes**
Based on the current video frame on your screen, here are the high-level notes explaining the Kubernetes architecture and the workflow depicted:

## Architecture Components

The architecture is divided into two main areas:

### 1. Control Plane / Master Node

* **API Server (`APISERVER`):** Acts as the central hub and entry point. All communication between components (and from the user) goes through it. It handles authentication and validation.
* **ETCD:** The cluster's distributed database that stores the state and configuration data. Only the API Server talks directly to ETCD to retrieve or update information.
* **Scheduler (`SCHEDULAR`):** Watches for newly created Pods that have no node assigned and selects the best Worker Node for them to run on.
* **Controller Manager:** Manages various controllers that regulate the state of the cluster (making sure the actual state matches the desired state).

### 2. Worker Node

* **Kubelet:** An agent that runs on each node in the cluster. It ensures that containers are running in a Pod by communicating with the API Server.
* **Kube-Proxy:** Manages network rules on nodes, allowing network communication to your Pods from inside or outside the cluster.
* **Pod:** The smallest deployable units of computing that you can create and manage in Kubernetes, which wrap the application container.

---

## The Step-by-Step Workflow (Creating a Pod)

The text on the right side of the screen outlines exactly what happens when a user requests a new pod:

1. **User Initiation:** The user executes a command like `kubectl create pod`.
2. **API Server Processes:** The API Server **authenticates** the user, **validates** the request, and **retrieves/updates** the data in **ETCD**.
3. **Scheduling:** The API Server gets a response **from the scheduler** indicating which node is "found" or chosen for the Pod.
4. **Node Deployment:** The API Server **sends** the instruction to the **Kubelet** on the selected Worker Node.
5. **Confirmation:** A **response** goes back to the **API Server**, which then finalizes the status and returns a success confirmation back to the **client/user**.
---
* **Click to read more :** https://devopscube.com/kubernetes-architecture-explained/