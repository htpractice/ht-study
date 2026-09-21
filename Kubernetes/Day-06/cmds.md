# This is the list of commands used in day06 practice

| Command | Use |
|---------|-----|
| kind create cluster --config kind-example-config.yaml | Creates a new Kubernetes cluster using the provided config file. |
| kubectl cluster-info --context kind-kind | Displays cluster info for the specified context. |
| curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/arm64/kubectl" | Downloads the latest version of kubectl for Mac ARM64. |
| echo "$(cat kubectl.sha256)  kubectl" &#124; shasum -a 256 --check | Validates the downloaded kubectl binary's checksum. |
| chmod +x ./kubectl | Makes the kubectl binary executable. |
| sudo mv ./kubectl /usr/local/bin/kubectl | Moves kubectl to a directory in your PATH. |
| sudo chown root: /usr/local/bin/kubectl | Changes ownership of kubectl binary to root. |
| kubectl version --client | Shows the version of your local kubectl client. |
| kubectl version --client --output=yaml | Shows client version in YAML format. |
| kubectl cluster-info | Displays info about the current Kubernetes cluster. |
| brew install go | Installs the Go programming language using Homebrew. |
| kind cluster info | Prints information about the cluster created by kind. |
| kind cluster list | Lists all clusters managed by kind. |
| kind list cluster | Lists clusters (alternative command, may be incorrect or deprecated). |
| kind get cluster | Retrieves cluster information (may be incorrect, check CLI docs). |
| kind get clusters | Lists all kind clusters. |
| kind delete clusterkind | Likely a typo; intended to delete a named cluster. |
| kind delete cluster kind | Deletes a cluster named 'kind'. |
| kind delete cluster kind-example-config.yaml | Attempts to delete a cluster (incorrect syntax; should use cluster name not file). |
| kind delete cluster kind-example | Deletes a cluster named 'kind-example'. |
| kind get clusters | Lists all kind clusters. |
| kind delete cluster | Deletes the default kind cluster. |
| kind get clusters | Lists all kind clusters. |
| kind create cluster --image kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5 | Creates a new cluster with a specified node image/version. |
| kind delete cluster | Deletes the default kind cluster. |
| kind create cluster --image kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5 --name cka-cluster01 | Creates a new cluster with a custom name and node image/version. |
| kubectl cluster-info --context kind-cka-cluster01 | Shows cluster info for the "cka-cluster01" context. |
| alias kc='kubectl' | Creates an alias "kc" for the kubectl command for quicker access. |
| kc get pods | Lists the pods in the current namespace. |
| vim ~/.bashrc | Opens the bash profile in vim for editing aliases or environment variables. |
| kc --version client | Shows the kubectl client version (may be a typo; should be `kubectl version --client`). |
| kc --version | Shows the kubectl version information. |
| kc get nodes | Lists all nodes in the Kubernetes cluster. |
| kind create cluster --image kindest/node:v1.36.1@sha256:3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5 --name cka-cluster02 --config multi-node.yaml | Creates a new multi-node cluster using a config file and custom name/image. |
| kc get nodes | Lists all nodes to confirm multi-node setup. |
| kc config get-context | Gets the current context (may be a typo; correct is `kubectl config get-contexts`). |
| kc config get-contexts | Lists all Kubernetes contexts on your system. |