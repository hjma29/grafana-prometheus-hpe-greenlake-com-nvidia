

Currently I have two cluster, p1 running prometheous and c2 running nvidia gpu-operator. Longer term maybe just run one cluster for simplicity

Have two K8s cluster running. 
### The p2 cluster has grafana-prometheus in "monitoring" namespace.

p1-cluster running grafana/prometheus. Main prometheus-grafana svc set up as NodePort on port 31600.  launch web browser to the p1-worker-vm:31600, the login default is "admin/prom-operator"
