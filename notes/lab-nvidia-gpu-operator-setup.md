

Currently I have two cluster, p1 running prometheous and c2 running nvidia gpu-operator. Longer term maybe just run one cluster for simplicity

Have two K8s cluster running. 
The p2 cluster has grafana-prometheus in "monitoring" namespace.

p1-cluster running grafana/prometheus. Main prometheus-grafana svc set up as NodePort on port 31600.  launch web browser to the p1-worker-vm:31600, the login default is "admin/prom-operator"

``` text
wsl=> k config current-context
p1-admin@p1.grafana

wsl=> k get node
NAME                                STATUS   ROLES           AGE   VERSION
p1-master-vm.hst.enablement.local   Ready    control-plane   79d   v1.33.1
p1-worker-vm.hst.enablement.local   Ready    <none>          79d   v1.33.1
hjma@HSTHJMA02:~


wsl=> k get svc -n monitoring
NAME                                       TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
alertmanager-operated                      ClusterIP   None             <none>        9093/TCP,9094/TCP,9094/UDP   54d
prometheus-operated                        ClusterIP   None             <none>        9090/TCP                     54d
test-prometheus-grafana                    NodePort    10.97.92.135     <none>        80:31600/TCP                 54d
test-prometheus-kube-prome-alertmanager    ClusterIP   10.100.1.114     <none>        9093/TCP,8080/TCP            54d
test-prometheus-kube-prome-operator        ClusterIP   10.100.184.136   <none>        443/TCP                      54d
test-prometheus-kube-prome-prometheus      ClusterIP   10.107.215.146   <none>        9090/TCP,8080/TCP            54d
test-prometheus-kube-state-metrics         ClusterIP   10.101.113.18    <none>        8080/TCP                     54d
test-prometheus-prometheus-node-exporter   ClusterIP   10.100.132.103   <none>        9100/TCP                     54d

wsl=> curl 10.16.160.42:31600
<a href="/login">Found</a>.
```

In p1 cluster, the grafana/prometheus was set up using helm
``` text

wsl=> helm list -A --filter 'prometheus'
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS    CHART                            APP VERSION
test-prometheus monitoring      3               2025-07-22 17:11:52.125453 -0700 MST    deployed  kube-prometheus-stack-75.4.0     v0.83.0
hjma@HSTHJMA02:~

wsl=> helm -n monitoring get values test-prometheus --revision 3
USER-SUPPLIED VALUES:
prometheus:
  prometheusSpec:
    additionalScrapeConfigs:
    - job_name: c2-dcgm-exporter
      static_configs:
      - targets:
        - 10.16.160.54:30639
        - 10.16.160.54:30639
hjma@HSTHJMA02:~
wsl=> helm -n monitoring get values test-prometheus --revision 2
USER-SUPPLIED VALUES:
prometheus:
  prometheusSpec:
    additionalScrapeConfigs:
    - job_name: c2-dcgm-exporter
      static_configs:
      - targets:
        - 10.16.160.54:31065
        - 10.16.160.55:31065
hjma@HSTHJMA02:~
wsl=> helm -n monitoring get values test-prometheus --revision 1
USER-SUPPLIED VALUES:
null
hjma@HSTHJMA02:~
```