❯ kubectl logs loki-grafana-59b7c6dd8c-t85rt -c grafana -n observability | grep error
logger=sqlstore.transactions t=2026-08-06T10:22:18.603414961Z level=info msg="Database locked, sleeping then retrying" error="database is locked" retry=0 code="database is locked"
logger=provisioning t=2026-08-06T10:22:18.606833419Z level=error msg="Failed to provision data sources" error="Datasource provisioning error: data source with the same name already exists"
logger=context userId=1 orgId=1 uname=admin t=2026-08-06T10:22:18.607591836Z level=error msg= error="Datasource provisioning error: data source with the same name already exists" remote_addr=[::1] traceID=
logger=context userId=1 orgId=1 uname=admin t=2026-08-06T10:22:18.607848461Z level=error msg="Request Completed" method=POST path=/api/admin/provisioning/datasources/reload status=500 remote_addr=[::1] time_ms=37 duration=37.317583ms size=48 referer= handler=/api/admin/provisioning/datasources/reload
logger=tsdb.loki endpoint=checkHealth pluginId=loki dsName=Loki dsUID=P8E80F9AEF21F6940 uname=admin fromAlert=false t=2026-08-06T10:25:01.827814092Z level=error msg="Error received from Loki" duration=26.255125ms stage=databaseRequest statusCode=400 contentLength=65 start=1970-01-01T00:00:01Z end=1970-01-01T00:00:04Z step=1s query=vector(1)+vector(1) queryType=instant direction=backward maxLines=0 supportingQueryType=none lokiHost=loki:3100 lokiPath=/loki/api/v1/query status=error error="parse error at line 1, col 1: syntax error: unexpected IDENTIFIER"
logger=tsdb.loki endpoint=checkHealth pluginId=loki dsName=Loki dsUID=P8E80F9AEF21F6940 uname=admin fromAlert=false t=2026-08-06T10:25:01.827891134Z level=error msg="Error querying loki" error="parse error at line 1, col 1: syntax error: unexpected IDENTIFIER"
logger=tsdb.loki endpoint=CheckHealth t=2026-08-06T10:25:01.827904092Z level=error msg="Loki health check failed" error="error from loki: parse error at line 1, col 1: syntax error: unexpected IDENTIFIER"
❯ kc get pods,svc -n observability
NAME                                READY   STATUS    RESTARTS   AGE
pod/loki-0                          1/1     Running   0          11m
pod/loki-grafana-59b7c6dd8c-t85rt   2/2     Running   0          11m
pod/loki-promtail-9fqth             1/1     Running   0          11m
pod/loki-promtail-j4q9z             1/1     Running   0          11m
pod/loki-promtail-mvpsl             1/1     Running   0          11m

NAME                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/loki              ClusterIP   10.96.187.199   <none>        3100/TCP   11m
service/loki-grafana      ClusterIP   10.96.155.103   <none>        80/TCP     11m
service/loki-headless     ClusterIP   None            <none>        3100/TCP   11m
service/loki-memberlist   ClusterIP   None            <none>        7946/TCP   11m
❯ curl 10.96.187.199 3100
^C
❯ kc exec -it pod/loki-grafana-59b7c6dd8c-t85rt -n observability -- bash
Defaulted container "grafana-sc-datasources" out of: grafana-sc-datasources, grafana
error: Internal error occurred: Internal error occurred: error executing command in container: failed to exec in container: failed to start exec "1b2a91ca0c41a12fb16642412d91c0b6e58adee7a9a180b87e70cf48a5285b59": OCI runtime exec failed: exec failed: unable to start container process: exec: "bash": executable file not found in $PATH
❯ kc exec -it pod/loki-grafana-59b7c6dd8c-t85rt -n observability -- sh
Defaulted container "grafana-sc-datasources" out of: grafana-sc-datasources, grafana
/app $ curl
sh: curl: not found
/app $ apt-get
sh: apt-get: not found
/app $ exit
command terminated with exit code 127
❯ kc exec -it pod/loki-grafana-59b7c6dd8c-t85rt -n observability -c grafana -- sh
/usr/share/grafana $ curl
curl: try 'curl --help' or 'curl --manual' for more information
/usr/share/grafana $ curl -s -o /dev/null -w "%{http_code}\n" http://loki:3100/ready
200
/usr/share/grafana $ curl -s http://loki:3100/ready
ready
/usr/share/grafana $ curl -s http://loki:3100/loki/api/v1/labels
{"status":"success","data":["app","component","container","filename","instance","job","namespace","node_name","pod","stream"]}
/usr/share/grafana $ curl -s http://loki:3100
404 page not found
/usr/share/grafana $ curl -s http://loki:3100/
404 page not found
/usr/share/grafana $ curl -s http://loki:3100/ready
ready
/usr/share/grafana $ curl -s http://loki:3100
404 page not found
/usr/share/grafana $ curl -s http://loki:3100/loki
404 page not found
/usr/share/grafana $ curl -s http://loki:3100
404 page not found
/usr/share/grafana $ curl 10.96.187.199
^C
/usr/share/grafana $ curl loki.observability.svc.cluster.local 3100
^C
/usr/share/grafana $ cat /etc/resolv.conf
search observability.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5
/usr/share/grafana $ curl loki.observability.svc.cluster.local:3100
404 page not found
/usr/share/grafana $ telnet
sh: telnet: not found
/usr/share/grafana $ spt-get install net-tools
sh: spt-get: not found
/usr/share/grafana $ apt-get install net-tools
sh: apt-get: not found
/usr/share/grafana $ uname -a
Linux loki-grafana-59b7c6dd8c-t85rt 6.10.14-linuxkit #1 SMP Tue Oct 14 07:32:13 UTC 2025 aarch64 Linux
/usr/share/grafana $ yum install telnet
sh: yum: not found
/usr/share/grafana $ dnf install telnet
sh: dnf: not found
/usr/share/grafana $ curl -s http://loki:3100/loki/api/v1/status/buildinfo
{"version":"2.6.1","revision":"6bd05c9a4","branch":"HEAD","buildUser":"root@f74391434100","buildDate":"2022-07-18T08:48:43Z","goVersion":""}
/usr/share/grafana $ exit





