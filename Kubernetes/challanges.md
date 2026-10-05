# Round 2 Prep — SRE Challenges

## Part 1: SRE Scripting Challenges (Python)

### Scenario A: Multi-Cluster GitOps Drift Detector (IaC / GitOps)

**The problem:** You use Argo CD, but a developer manually bypassed the pipeline and ran `kubectl patch` or used the AWS console to modify a live resource. You need a fast script to check an infrastructure definition file against live state.

**Coding task:** Write a Python function that takes:

- a template JSON object (desired state), and
- a live fetched API JSON object (actual state),

recursively traverses both, and returns a dictionary of keys where the values drifted or are missing in the live environment.

**What they test:** Deep dictionary traversal, nested structures, and data validation without external libraries.

---

### Scenario B: Cluster Upgrade Log Parser & Incident Locator (K8s / CI/CD)

**The problem:** A rolling cluster upgrade just kicked off across 50 nodes. Three nodes failed to join the cluster due to a missing CNI lease issue (similar to your Flannel problem). You have a massive text log file dumped by the CI/CD pipeline.

**Coding task:** Write a memory-efficient script (using generators) that scans the file line-by-line with regex. It must:

- extract all occurrences of `Error registering network` or `connection refused`,
- correlate them with the timestamp and node ID found earlier in the text block, and
- output a clean JSON summary of affected nodes.

**What they test:** Streaming large files without blowing up RAM, regular expressions, and log parsing.

---

## Part 2: High-Stake Senior SRE Interview Questions (By Topic)

Review these scenario questions for strategic discussion in this round.

### 1. Cloud & Kubernetes at Scale

**Scenario:** You have a cluster running hundreds of pods. An HPA triggers an upscale event, but new pods are stuck in `Pending` because EC2 nodes are full. Cluster Autoscaler is provisioning new nodes, but boot takes ~2 minutes. During that window, traffic spikes and packets drop.

**Interviewer question:** How do you solve this cold-start scaling latency? Explain over-provisioning / PriorityClass pause pods and how you configure Pod Disruption Budgets (PDB) to protect critical apps during upgrades.

### 2. IaC & GitOps Drift Management

**Scenario:** You run an Argo CD GitOps pipeline. A stateful service relies on a Terraform-managed AWS EBS volume. A developer changes the EBS volume type manually in the AWS console to save money, causing drift between Git, Terraform state, and live AWS infrastructure.

**Interviewer question:** How do you architect an automated pipeline that detects drift between Terraform state and live cloud resources? If Argo CD and Terraform conflict over who owns a resource's configuration, how do you resolve that ownership boundary?

### 3. Data Infrastructure Operations (Kafka / PostgreSQL / OpenSearch)

**Scenario:** You manage a multi-region Kafka cluster across two AWS regions (e.g. `us-east-1` and `us-west-2`). Network latency between regions spikes unexpectedly by 200 ms.

**Interviewer question:** How do you configure replication factors and `min.insync.replicas` to prevent message loss during a cross-datacenter partition? For PostgreSQL or OpenSearch, what are the trade-offs between synchronous and asynchronous replication when handling regional failover?

### 4. Security Hardening & Zero-Trust

**Scenario:** A critical CVE affects the base Linux image used by 80% of production microservices.

**Interviewer question:** Walk through an automated pipeline for CVE remediation at scale without massive downtime. How do you implement Kubernetes Network Policies so a compromised pod cannot laterally reach internal data infrastructure (Postgres, Kafka brokers, etc.)?
