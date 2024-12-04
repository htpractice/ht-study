## Notes for Observability

- Monitoring and fixing the system state to maintain SLA is called obervability in nutshell.
- Monitoring only covers 1 pillar of observability i.e Metrics and its associated dashboards.
- Observability is made of three words Metrics Logging Traces

### 3 key words for systemstate
# What? (what is happening to my systemstate?)
- Metrics from servers or applications -> historical information provider
# Why? (why this is happening to my systemstate?)
- Logging or logs obtained from servers or applications -> Logs from metrics i.e on how that event occur
# How? (how is this happening to my systemstate?)
- Traces on how the error has occured -> starting from client side to endpoint in our applications.


# Metrics (Historic Data of the event )
- CPU, MEM , DISK, HTTP Requets are few types of metrics

# Logging
- Info, Debug, Error, Trace are types of log

# Traces
- Allows debug and trobleshoot by showing us the entire path the request has taken.

# SLA
    Aggrement with customer to keep servies up all the time
# SLO
    Keeping infra up 99.9999 will be up or out of 10000 req 99999 req repond back in 200ms
# SLI
    Observability platform covers the state of system to meet SLO's by defining indicators like error rates,CPU, MEM etc.

# Collective Approach of Developer and SRE/Devops
- Developer need to instrument Metrics , Logs and Traces in application using open-telementry or prom-client
- Devops/SRE need to setup obervability stack for the application which can collect the metrics , alert the engineers for any anamoly and provide a path (trace) for the request using promethus, grafana, ELK etc.

# Observability stack
    - Promethus = Collects data from nodes using exporters
    - Alertmanger = Alerts the SRE's about the potential issue based on hte data received from prometheus and thresholds set
    - Grafana = visualize the data stored in Time Lapsed DB of Prometheus for all the metrices (we can use service discovery in grafana to add application level metrices for applications)
    - Opentelementary = Instrumentation for application level metrice which are designed or add by app developers to the applicataion
    - Daynatrace/Datadog/Jager = To visualise these traces (agent based tool , agents are added to nodes and clusters which scraps the data and sends to the tool)
    - ELK = Logging stack for logging the systestate data for troubleshooting the issues.
- Together the tools forms a stack which can help acheive the SLO defined for the services my providing granular level monitoing of metrices.

# Types of exporter 
    - Node-exporter = added to all the nodes in cluster to get metrics like cpu, mem, disk etc
    - kube-state-exprter = added to all the kubernetes cluster to get metrics for pod
