# Monitoring HPE GreenLake Servers running GPU using Grafana and Prometheus


## Overview
HPE GreenLake provides a cloud-native platform for managing and monitoring infrastructure with built-in tools and dashboards. While GreenLake offers comprehensive native monitoring capabilities, organizations can also leverage the GreenLake API to integrate with popular open-source tools like Grafana and Prometheus. This approach enables teams to consolidate monitoring data across hybrid environments, utilize existing observability workflows, and create customized dashboards tailored to specific operational needs.


## Kubernetes and Helm Setup
### Environment Verification

Before proceeding with the monitoring setup, verify that your Kubernetes cluster has the necessary components installed. The following shows a working environment with the GPU Operator and Prometheus monitoring stack deployed:

**Services running in the gpu-operator namespace:**
- `gpu-operator`: Core service for GPU management (ClusterIP: 10.233.44.80:8080)
- `nvidia-dcgm-exporter`: DCGM metrics exporter for Prometheus integration (ClusterIP: 10.233.15.59:9400)

**Helm releases:**
- `gpu-operator-1753140595` (v25.3.2) in the `gpu-operator` namespace
- `kube-prometheus-stack` (76.3.0) in the `monitoring` namespace

You can verify your setup using the following commands:

```
wsl=> k get svc -n gpu-operator 
NAME                   TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
gpu-operator           ClusterIP   10.233.44.80   <none>        8080/TCP   78d
nvidia-dcgm-exporter   ClusterIP   10.233.15.59   <none>        9400/TCP   78d

wsl=> helm list -A
NAME                    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                           APP VERSION
gpu-operator-1753140595 gpu-operator    4               2025-08-14 19:20:42.329819669 -0700 MST deployed        gpu-operator-v25.3.2            v25.3.2    
kube-prometheus-stack   monitoring      5               2025-08-15 13:06:31.169338089 -0700 MST deployed        kube-prometheus-stack-76.3.0    v0.84.1    
hjma@HSTHJMA02:~
```