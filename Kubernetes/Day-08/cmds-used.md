# This is the list of commands used in day06 practice

| Command                                                           | Use                                                                                     |
|-------------------------------------------------------------------|-----------------------------------------------------------------------------------------|
| kc edit rs/nginx-rs                                               | Opens the ReplicaSet `nginx-rs` in the default editor for live editing.                 |
| kc get po                                                         | Lists all pods in the current namespace.                                                |
| kc get rs                                                         | Displays a list of all ReplicaSets in the current namespace.                            |
| kc delete rs                                                      | Deletes all ReplicaSets in the current namespace. (Caution: Bulk delete operation)      |
| kc delete rs/nginx-rs                                             | Deletes the specific ReplicaSet named `nginx-rs`.                                       |
| kc apply -f deploy.yml                                            | Applies the configuration in `deploy.yml` (creates or updates resources).               |
| kc get deploy                                                     | Lists all deployments in the current namespace.                                         |
| kc get deploy -o wide                                             | Lists all deployments with extended details (includes additional columns).               |
| kc get rs -o wide                                                 | Shows all ReplicaSets with extra information for each.                                  |
| kc get pods -o wide                                               | Lists pods with extended information (IP, node, etc).                                   |
| kc get all                                                        | Shows all resources in the namespace (pods, svc, rs, deploy, etc.).                    |
| kc delete all                                                     | Deletes all resources in the current namespace (be careful: nuclear option).            |
| kc set image deploy/nginx-deploy \nnginx=nginx:1.9.1              | Updates the `nginx` container image in `nginx-deploy` deployment to version 1.9.1.      |
| kc set image deploy/nginx-deploy \nnginx-deploy=nginx:1.9.1       | Attempts to update a container named `nginx-deploy` in the deployment to 1.9.1 image.   |
| kc set image deploy/nginx-deploy \nnginx-container=nginx:1.9.1    | Updates the `nginx-container` image in `nginx-deploy` deployment to version 1.9.1.      |
| kc describe deploy/nginx-deploy                                   | Shows detailed status and configuration for deployment `nginx-deploy`.                  |
| kc rollout history deploy/nginx-deploy                            | Displays the rollout revision history for the `nginx-deploy` deployment.                |
| kc rollout undo deploy/nginx-deploy                               | Rolls back the `nginx-deploy` deployment to the previous revision.                      |