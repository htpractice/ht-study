# This project will focus on creating a production level ISOLATED messaging service using RabbitMQ, Grafana and Prometheus
# Tier 1 (Frontend):
- ALB: For accessing RabbitMQ's management UI (HTTP on port 15672).
- Grafana: For monitoring the RabbitMQ cluster.

# Tier 2 (Backend):
- RabbitMQ Nodes: Handling message queuing and AMQP communication (port 5672).
- Prometheus: Scraping metrics from RabbitMQ for monitoring.

# RabbitMQ Installation:
- Setting up a Rabbit MQ Cluster
    - Pre-requists:
        - 3 EC2 nodes with port 22, 5672 and 15672 inboound and outbound ALL ALL setup in private subnet
        - I am using a AMZ linux to setup the cluster hence we need to setup yum repo for the rabbit-mq
        - Follow [RabbitMQ Installation](https://www.rabbitmq.com/docs/install-rpm#managing-service)
    - Configuring Cluster:
        - Enable plugins on all nodes
            rabbitmq-plugins enable rabbitmq_management
            rabbitmq-plugins enable rabbitmq_peer_discovery_aws
        - Create local dns by adding the following entries for your nodes
                    10.0.0.101 rabbitmq-node1
                    10.0.0.102 rabbitmq-node2
                    10.0.0.103 rabbitmq-node3
        - Chnage the env config for nodes to assogn nodenames similar to what is added in local DNS
                1 - echo "NODENAME=rabbit@rabbitmq-node1" >> /etc/rabbitmq/rabbitmq-env.conf
                2 - echo "NODENAME=rabbit@rabbitmq-node2" >> /etc/rabbitmq/rabbitmq-env.conf
                3 - echo "NODENAME=rabbit@rabbitmq-node3" >> /etc/rabbitmq/rabbitmq-env.conf
        - Add the cluster config to rabbitmq config
        - configure rabbitMq cluster to listen on 0.0.0.0:15672 as we will be using LB as our frontend or if you want you can change the IP to LB IP.
        - check the cluster status you should see all the nodes.
                     rabbitmqctl status
        - For any app to send the messages to rabbitMQ port 5672 will be used so make sure both are enabled.
        - Add the user
            sudo rabbitmqctl add_user <username> <password>
            sudo rabbitmqctl set_user_tags <username> administrator
            sudo rabbitmqctl set_permissions -p / <username> ".*" ".*" ".*"
        - Above user will be used to access UI

# Internal Loadbalancer for RabbitMQ UI
- Setting up the ALB for accessing the RabbitMQ UI
    - Setup an application loadbalancer as internal
    - Add the rabbitMQ cluster nodes as target groups
    - Add Bastion private cidr block or subnet to LB SG to allow connectivity on port 15672
- Setup a UI based linux or a windows bastion which can be used to connect the rabbitMQ from browser.
(orgs have VPN which can resolve the private IP's in cloud space based on internal DNS setup so we can use rabbitMQ from local machine)
- Note:
    ALB: Use for RabbitMQ UI (15672) since it supports HTTP/HTTPS, which browsers use.
    NLB: Use for AMQP traffic (5672) for efficient, low-latency TCP communication with hosts in production.
(for cost saving we can use ALB for both the purposes but NLB provides high throughput hence we can do a small tweek we can just us NLB for amq requests on 5672 and use the cluster node private IP or hostname to have rabbit MQ UI on 15672.)

# Install Prometheus for data scrapping
[docker prom installation](https://prometheus.io/docs/prometheus/latest/installation/)
- We are using prom/prometheus docker image to rum latest prom with all binaries.
- Get into server in private subnet where you want to run prometheus and grafana on same host.
- Expose prometheus container to listen on any host address.
- bind-mount the directory containing prometheus.yml onto /etc/prometheus so that we can have access to prom files on local host
- enable prometheus plugin
        rabbitmq-plugins enable rabbitmq_prometheus
- we need to make sure that the rabbitmq nodes are scrapping data on 15692
        curl -s localhost:15692/metrics | head -n 3
- we are creating a local prometheus.yml with following config
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'rabbitmq'
    static_configs:
      - targets:
        - '10.100.1.210:15692'
        - '10.100.1.28:15692'
        - '10.100.1.221:15692'

docker run --name prometheus -d -p 10.100.1.74:9090:9090 -v /root/prometheus:/etc/prometheus prom/prometheus

# Install Grafana for data visualization:
- Using below command will install garfana as containerized application
- Using /data to make it persistent
docker run -d --name=grafana -p 10.100.3.190:3000:3000  grafana/grafana-enterprise:11.4.0-ubuntu
- To make grafana persistent like promethrus config we can use -v /root/data/provisioning:/var/lib/provisioning -v /root/data/dashboards:/var/lib/dashboards kind of options
- Used prometheus as data exporter source.