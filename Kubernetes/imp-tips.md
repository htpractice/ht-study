Youtube Video Ref: [https://www.youtube.com/watch?v=_f9ql2Y5Xcc](https://www.youtube.com/watch?v=_f9ql2Y5Xcc)

---

To pass the CKA exam and operate at an SRE level, you will indeed need to master the areas that go beyond this high-level overview, such as:

- **Advanced Networking:** Understanding the *Container Network Interface (CNI)*, how *CoreDNS* functions, and managing complex traffic routing via *Ingress* and *Network Policies*.
- **Storage Administration:** Configuring *Persistent Volumes (PV)*, *Persistent Volume Claims (PVC)*, and managing *StorageClasses*.
- **Cluster Maintenance:** Performing backups of *etcd*, managing *TLS certificates*, and performing rolling upgrades of the cluster.
- **Troubleshooting:** Deep-diving into control plane health and node-level debugging.

As the course progresses, the instructor will likely move from "what the components are" to "how to manage, secure, and troubleshoot them in a real-world environment." This foundational video is the necessary first step, but you are right to look forward to the more technical depth required for the certification.

---

### **Exam Tips**

- You can use following links in exam for command references
  - [https://kubernetes.io/docs/home/](https://kubernetes.io/docs/home/)
  - [https://kubernetes.io/docs/reference/kubectl/](https://kubernetes.io/docs/reference/kubectl/)
- Always read the question carefully and see which context it belongs to , so basically switch to a new context if needed to answer the question correctly using following command
  - **kc config get-contexts** 
    - (* mark means current context and kubectl command will return the data from curent cluster only.)
  - **kc config set-contexts <context/cluster name you want to troubleshoot>**
- For the **CKA exam**, you will be using the `vi` or `vim` editor. Adjusting indentation in large YAML files manually is indeed inefficient. Here are the most effective ways to manage indentation within `vi`:

### **1. Visual Mode Indentation (Best for chunks)**
This is the most common technique for adjusting blocks of code:
* **Select the block:** Press `v` (visual mode) and use arrow keys or `j`/`k` to highlight the lines you want to fix.
* **Indent Right:** Press `>` (Shift + `.` in most layouts).
* **Indent Left:** Press `<` (Shift + `,`).
* *Pro tip:* You can press `>>` or `<<` while in Command Mode to indent/unindent the current line instantly.

### **2. Global Automatic Reformatting**
If you have `vim` installed and want to attempt to fix the formatting of the entire file, you can use:
* `gg=G`: This command jumps to the beginning (`gg`), performs an equal sign operation (`=`)—which is the built-in auto-indent command—across the entire file to the end (`G`).
* *Note:* This works best if your indentation structure is generally correct but just misaligned.

### **3. Setting Editor Preferences**
Before you start editing a file, you can tell `vi` how to handle indentation automatically to prevent errors as you type:
* Type `:set autoindent` to have new lines follow the indentation of the previous one.
* Type `:set shiftwidth=2` or `:set tabstop=2` to ensure the editor uses **2 spaces** for indentation, which is the standard for **Kubernetes YAML manifests**.

### **CKA Exam Strategy**
Since time is critical, don't rely solely on fixing broken manifests. 
* **Use `dry-run` to generate clean YAML:** Instead of writing from scratch, use **`kubectl run <name> --image=<image> --dry-run=client -o yaml > pod.yaml`**. This ensures your base structure is perfectly indented from the start.
* **Use `kubectl edit`:** When editing a running object, the `kubectl` tool typically maintains valid YAML structure automatically, which reduces the chance of manual indentation errors.

