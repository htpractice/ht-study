This video serves as a comprehensive tutorial on **Kubernetes Ingress**, explaining how it functions as a crucial component for managing external access to services within a cluster. The speakers, *Piyush Sachdeva* and guest *Abhishek Veeramalla*, break down the concept from basic networking needs to a practical, step-by-step implementation.

### Why Ingress is Necessary
In a standard *Kubernetes* environment, applications (Pods) are only accessible internally. While services of type *NodePort* or *LoadBalancer* exist to expose applications, they have significant drawbacks:
* **Cloud Dependency:** *LoadBalancer* services rely heavily on specific cloud provider implementations.
* **Cost:** Using a dedicated *LoadBalancer* for every single service is expensive and inefficient at scale.
* **Security and Flexibility:** Traditional *LoadBalancer* services often lack advanced traffic management features like request filtering, rate limiting, or custom routing rules found in traditional virtual machine setups.

*Ingress* addresses these issues by acting as an entry point that provides advanced load balancing, SSL termination, and name-based/path-based routing without requiring a separate *LoadBalancer* service for every application.

### Core Components
To implement *Ingress*, the video identifies three primary entities:
* **Ingress Resource:** A declarative *YAML* file that defines routing rules (e.g., which host or path should be directed to which service).
* **Ingress Controller:** A specialized software program (commonly *NGINX*) that monitors the *Ingress* resource. It translates the rules you defined into actual configuration for a load balancer.
* **Load Balancer:** The actual infrastructure component that receives incoming traffic and distributes it based on the *Ingress Controller's* configuration.

### Practical Implementation
The video walks through a full demonstration using a *Python Flask* application:
1. **Containerization:** They build and push a *Docker* image to a registry.
2. **Deployment and Service:** They set up a standard *Deployment* and a *ClusterIP* service to make the application reachable internally.
3. **Ingress Controller Installation:** They install the *NGINX Ingress Controller*, which handles the logic for incoming requests.
4. **Ingress Configuration:** They define the *Ingress* resource, specifying the host (e.g., *example.com*) and the path. 
5. **Resolution:** Because the demo uses a local cluster without a public DNS, they demonstrate how to map a host name to an IP address manually, simulating a real-world DNS setup.

### Key Takeaways
* **Ingress Class:** The speakers emphasize the importance of the `ingressClassName` field. This ensures that in a cluster with multiple controllers (like *NGINX* and *Kong*), the correct controller handles the specific *Ingress* resource.
* **Troubleshooting:** The video demonstrates practical debugging techniques, such as checking logs and verifying service types when external IP addresses fail to populate due to environment limitations (like missing cloud controller managers).
* **The Workflow:** The final flow of traffic is external request $→$ Ingress $→$ Service $→$ Pod.



ow does the Ingress Controller read the YAML?
Why is the ingressClassName field important?
What is the difference between LoadBalancer and Ingress?

The speakers clarify that while both methods are used to expose applications, they differ significantly in cost, management, and capabilities:
Service of type LoadBalancer: This creates a dedicated load balancer provided by your cloud provider for every service. The speaker notes this is often expensive because you are charged for each load balancer you create (4:16-6:16).
Ingress: This acts as a single entry point for your cluster. Instead of creating a new load balancer for every single service, you use one Ingress controller to manage routing rules. This allows for advanced features like host-based or path-based routing and is generally more cost-effective (7:48-14:14).



Why is LoadBalancer considered expensive?
What does an Ingress controller do?
What is Kubernetes Ingress?

The speakers define Kubernetes Ingress as a mechanism to handle inbound traffic, or the 'inward traffic' coming into a cluster from the external world (09:57 - 10:25). It functions as a critical layer for managing external access to services, which otherwise remain trapped within the internal cluster network (02:39 - 02:49).
According to the video, Ingress operates through three key components (10:28 - 10:53):
Ingress Resource: A declarative YAML file where developers define routing rules, such as specific host names (e.g., example.com) or paths for incoming traffic (12:00 - 12:04, 32:43 - 33:41).
Ingress Controller: A specialized program that acts as the 'brain' of the operation. It monitors the Ingress resource and translates these high-level routing rules into actual load balancer configurations (12:12 - 12:49, 34:49 - 35:01).
Load Balancer: The infrastructure piece that actually receives the traffic and directs it to the appropriate service based on the controller's instructions (14:52 - 15:23).
By adding this layer, users can move beyond simple, expensive services of type 'LoadBalancer' and instead use a single, configurable entry point that enables advanced features like host-based or path-based routing (07:44 - 08:00, 18:43 - 19:18).



Why is using Ingress cheaper than LoadBalancer?
What does the Ingress class name do?
How do I create an Ingress resource?
How does Ingress handle routing?

In Kubernetes, Ingress provides a powerful way to manage external access to services, solving limitations associated with NodePort or LoadBalancer services. It acts as an entry point for traffic, enabling advanced features like host-based and path-based routing (18:43-19:21).
The traffic routing process relies on two distinct components:
Ingress Resource: This is a declarative YAML file where you define your routing rules. It specifies how incoming requests (e.g., example.com/api) should be mapped to internal services (33:02-33:39).
Ingress Controller: This is a specialized software program (such as NGINX) that continuously monitors the Kubernetes API for new Ingress resources. Once detected, the controller automatically configures the underlying load balancer based on the rules specified in your YAML (14:40-15:24, 34:49-35:01).
Key Operational Concepts:
Decoupling: The Ingress Resource defines what you want to happen, while the Ingress Controller handles how it is implemented by configuring the load balancer (15:05-15:24).
Ingress Class: Since a cluster might run multiple controllers (e.g., NGINX and Kong), using the ingressClassName field is vital. It ensures that only the intended controller processes your specific Ingress resource, preventing routing conflicts (39:00-39:53).
Traffic Flow: The final path for a request is: External Client → Load Balancer → Ingress Controller → Service → Pod (48:02-48:29).