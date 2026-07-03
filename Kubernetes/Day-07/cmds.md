# This is the list of commands used in day07 practice

| Command                                                        | Use                                                                                              |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `kc run nginx --image=ngix --dry-run=client -o yaml > ngix-pod-yml.yaml` | Generates the YAML manifest for a pod using the 'ngix' image without actually creating it. Useful for quickly creating a boilerplate YAML for declarative workflows. |
| `kc run nginx --image=ngix --dry-run=client -o json > ngix-pod-js.json`  | Same as above, but outputs the manifest in JSON format. Helpful if you prefer or require JSON for configurations. |
| `kc get pods`                                                  | Lists all pods in the current namespace, letting you see the state and status of your running pods. Useful for cluster monitoring. |
| `kc run pod ngix-pod.yml`                                      | Attempts to run a pod using the provided YAML file. Typically, 'apply' or 'create' is preferred for files. |
| `kc --help`                                                    | Shows help about the 'kc' (kubectl) command and all available options. Use it if you are unsure about command usage. |
| `kc create pod ngix-pod.yml`                                   | Creates a pod resource as defined in ngix-pod.yml. Appropriate when you want to create resources imperatively from a file. |
| `kc create ngix-pod.yml`                                       | Another way to create resources defined in the YAML file. The resource type is inferred from the contents of the file. |
| `kc apply -f ngix-pod.yml`                                     | Applies the configuration from ngix-pod.yml, creating or updating resources to match the desired state. Standard for declarative management. |
| `kc get pods --watch`                                          | Continuously watches pod status, updating in real-time as pods change state (Running, Pending, etc.). Essential for live monitoring. |
| `kc get pods`                                                  | Yet another listing; commonly used after changes to ensure things are as expected. |
| `kc describe pod ngix-pod`                                     | Shows detailed information and recent events for a specific pod, valuable for debugging and troubleshooting. |