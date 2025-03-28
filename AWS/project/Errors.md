# Cluster Connection error

[root@ip-10-100-1-221 ~]# rabbitmqctl stop_app
rabbitmqctl join_cluster rabbit@rabbitmq-node1
rabbitmqctl start_app
Stopping rabbit application on node rabbit@rabbitmq-node3 ...
Clustering node rabbit@rabbitmq-node3 with rabbit@rabbitmq-node1

03:51:02.864 [error] Feature flags: error while running:
Feature flags:   rabbit_ff_controller:running_nodes[]
Feature flags: on node `rabbit@rabbitmq-node1`:
Feature flags:   exception error: {erpc,noconnection}
Feature flags:     in function  erpc:call/5 (erpc.erl, line 1376)
Feature flags:     in call from rabbit_ff_controller:rpc_call/5 (rabbit_ff_controller.erl, line 1394)
Feature flags:     in call from rabbit_ff_controller:list_nodes_clustered_with/1 (rabbit_ff_controller.erl, line 486)
Feature flags:     in call from rabbit_ff_controller:check_node_compatibility_task/2 (rabbit_ff_controller.erl, line 398)
Feature flags:     in call from rabbit_db_cluster:can_join/1 (rabbit_db_cluster.erl, line 60)
Feature flags:     in call from rabbit_db_cluster:join/2 (rabbit_db_cluster.erl, line 92)
Feature flags:     in call from erpc:execute_call/4 (erpc.erl, line 1250)

Error:
{:aborted_feature_flags_compat_check, {:error, {:erpc, :noconnection}}}
Starting node rabbit@rabbitmq-node3 ...


# Things to check
1 - make sure all your ports mentioned in https://www.rabbitmq.com/docs/clustering#ports should be allowed in security groups
2 - verify the connectivity of ports from nodes too using telnet rabbitmq-node1 25672 telnet rabbitmq-node1 4369 from all the nodes
3 - Check the cookie value on each node and make sure all are same and the the perm of cookie file to 400
        chmod 400 /var/lib/rabbitmq/.erlang.cookie
        (this change helped me solve the only error I encountered during this process)
4 - Stop and Start the rabbit on node2 and node3 to join cluster
5 - validate if the port 15672 for UI and 5672 for amq is open and working using netstat or telnet command from all your nodes

# Unable to connect from UI using internal LB IP:<UI port>
1 Check for SG attached to LB it should allow the connection on 15672 (UI port) from the bastion subnet
2 Check the SG attached to cluster nodes it should allow the connection from LB subnet on port 15672
3 Configure the listeners for LB's as below
    ALB -> http 15672 (allow http on custom port and use the same port for health checks as well)
    NLB -> TCP 15672, TCP 5672 (allow tcp on custom port and use the same port for health checks as well 15672 is for UI and 5672 is for amq)
