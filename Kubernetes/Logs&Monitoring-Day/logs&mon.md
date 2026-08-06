This video provides an introductory guide to logging and monitoring within a Kubernetes environment, specifically tailored for those preparing for the CKA certification. It emphasizes that Kubernetes does not come with built-in monitoring, necessitating the use of add-ons like the Metrics Server to track resource utilization such as CPU and memory.

Key takeaways include:

* **Monitoring Architecture:** The video explains how data flows from *CAdvisor* (which collects metrics from container runtimes) to the *Kubelet*, and finally to the *Metrics Server*, where the information is exposed via an API for tools like *kubectl top*.
* **Logging Fundamentals:** Kubernetes logs are typically emitted to standard output or error streams. For professional environments, these are usually offloaded to third-party aggregation systems like *ELK* or *Splunk* to enable advanced observability and alerting.
* **Troubleshooting without Docker:** Because modern Kubernetes versions have shifted from *Docker* to *containerd*, the video demonstrates using the *crictl* command-line utility. This tool is essential for cluster administrators to debug container-level issues—such as failed pods or control plane components—especially when the API server or *kubectl* commands are unresponsive.

Overall, the session serves as a foundational bridge to more complex troubleshooting topics, including application and control plane failures that will be explored in subsequent parts of the series.



---

cluster level : Reeceives data from node -> Metric Servcer -> sends data to -> API Metric server (which can scale with HPA) -> sends to `kubectl top`

Node Level : cadvisor (container run time) + Pod data -> Kubelete -> Sends data to cluster