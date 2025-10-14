# Monitoring HPE GreenLake Servers running GPU using Grafana and Prometheus


## Overview
HPE GreenLake provides a cloud-native platform for managing and monitoring infrastructure with built-in tools and dashboards. While GreenLake offers comprehensive native monitoring capabilities, organizations can also leverage the GreenLake API to integrate with popular open-source tools like Grafana and Prometheus. This approach enables teams to consolidate monitoring data across hybrid environments, utilize existing observability workflows, and create customized dashboards tailored to specific operational needs.


## Kubernetes and Helm Setup
### Kubernetes cluster setup
This demonstration environment utilizes a high-availability Kubernetes cluster consisting of three control plane nodes and two worker nodes, 

``` bash
wsl=> k get node -o wide
NAME                                STATUS   ROLES           AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION       CONTAINER-RUNTIME
c2-cp-01.hst.enablement.local       Ready    control-plane   80d   v1.32.5   10.16.160.51   <none>        Ubuntu 22.04.5 LTS   5.15.0-144-generic   containerd://2.0.5
c2-cp-02.hst.enablement.local       Ready    control-plane   80d   v1.32.5   10.16.160.52   <none>        Ubuntu 22.04.5 LTS   5.15.0-144-generic   containerd://2.0.5
c2-cp-03.hst.enablement.local       Ready    control-plane   80d   v1.32.5   10.16.160.53   <none>        Ubuntu 22.04.5 LTS   5.15.0-144-generic   containerd://2.0.5
c2-worker-01.hst.enablement.local   Ready    <none>          80d   v1.32.5   10.16.160.54   <none>        Ubuntu 22.04.5 LTS   5.15.0-144-generic   containerd://2.0.5
c2-worker-02.hst.enablement.local   Ready    <none>          80d   v1.32.5   10.16.160.55   <none>        Ubuntu 22.04.5 LTS   5.15.0-144-generic   containerd://2.0.5
```
### Kubernetes namespace setup
The cluster is equipped with the `gpu-operator` namespace for NVIDIA GPU management and the `monitoring` namespace hosting the Prometheus stack, with external access enabled via NodePort services.
``` bash
wsl=> kubectl get ns | grep -vE '^(kube-|default)'
NAME              STATUS   AGE
gpu-operator      Active   80d
monitoring        Active   56d

wsl=> k get svc -n gpu-operator 
NAME                   TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
gpu-operator           ClusterIP   10.233.44.80   <none>        8080/TCP   78d
nvidia-dcgm-exporter   ClusterIP   10.233.15.59   <none>        9400/TCP   78d

wsl=> k get svc --field-selector spec.type=NodePort -n monitoring
NAME                               TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)                         AGE
kube-prometheus-stack-grafana      NodePort   10.233.22.241   <none>        80:30080/TCP                    56d
kube-prometheus-stack-prometheus   NodePort   10.233.8.106    <none>        9090:30090/TCP,8080:30398/TCP   56d
```

### Helm chart installation
The environment uses Helm to manage two key components: the NVIDIA GPU Operator for GPU resource management and the Kube Prometheus Stack for monitoring and observability.

``` bash
wsl=> helm list -A
NAME                    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                           APP VERSION
gpu-operator-1753140595 gpu-operator    4               2025-08-14 19:20:42.329819669 -0700 MST deployed        gpu-operator-v25.3.2            v25.3.2    
kube-prometheus-stack   monitoring      5               2025-08-15 13:06:31.169338089 -0700 MST deployed        kube-prometheus-stack-76.3.
0    v0.84.1    

```

### GPU Operator chart customization
The NVIDIA GPU Operator Helm chart deploys a DCGM (Data Center GPU Manager) exporter by default, but there are important nuances:

- The DCGM exporter Pod will be created automatically when the operator detects a node with an NVIDIA GPU and the dcgm-exporter component is enabled in its values.
``` bash
wsl=> k -n gpu-operator get pods -o wide | grep dcgm
nvidia-dcgm-exporter-gkg6d                                        1/1     Running     0          56d   10.233.117.209   c2-worker-01.hst.enablement.local   <none>           <none>
nvidia-dcgm-exporter-r2np6                                        1/1     Running     0          56d   10.233.114.15    c2-worker-02.hst.enablement.local   <none>           <none>
```


- In the stock gpu-operator Helm chart from NVIDIA's repository, the DCGM exporter is enabled by default (`dcgmExporter.enabled: true`), but the ServiceMonitor is disabled by default (`serviceMonitor.enabled: false`). See the [NVIDIA GPU Operator Documentation](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html#operator-install-guide).

![GPU Operator Configuration](images/image-4.png)

You can also verify these default built-in values using the `helm show values` command. 
``` bash
wsl=> helm show values nvidia/gpu-operator | grep -A 15 dcgmExporter
dcgmExporter:
  enabled: true
  repository: nvcr.io/nvidia/k8s
  image: dcgm-exporter
  version: 4.3.1-4.4.0-ubuntu22.04
  imagePullPolicy: IfNotPresent
  env: []
  resources: {}
  service:
    internalTrafficPolicy: Cluster
  serviceMonitor:
    enabled: false
    interval: 15s
    honorLabels: false
    additionalLabels: {}
    relabelings: []
```

We need to enable  the ServiceMonitor (`dcgmExporter.serviceMonitor.enabled: true`) in order for Prometheus to automatically scrape the DCGM exporter.


The gpu-operator is configured with custom values to enable Prometheus integration. The DCGM exporter runs as a ClusterIP service with ServiceMonitor enabled for automatic metrics discovery by Prometheus.
``` bash
wsl=> helm get values gpu-operator-1753140595 -n gpu-operator
USER-SUPPLIED VALUES:
dcgmExporter:
  service:
    type: ClusterIP
  serviceMonitor:
    enabled: true
    
```


### GPU utilization simulation
To simulate GPU load and verify monitoring functionality, we deployed a test pod running the gpu-burn utility. This tool performs intensive GPU computations, allowing us to observe GPU utilization metrics in our monitoring dashboards.

The following YAML manifest creates a pod that clones the gpu-burn repository, compiles it, and runs continuous GPU stress testing:

```yaml
apiVersion: v1
kind: Pod
metadata:
    name: gpu-burn
spec:
    containers:
        - name: gpu-burn
            image: nvidia/cuda:12.2.0-devel-ubuntu22.04 
            command: ["/bin/bash", "-c"]
            args:
                - |
                    apt update && apt install -y git build-essential && \
                    git clone https://github.com/wilicc/gpu-burn.git && \
                    cd gpu-burn && make && ./gpu_burn 999999 
            resources:
                limits:
                    nvidia.com/gpu: 1
    restartPolicy: Never
```

**Key configuration details:**
- **Base image**: `nvidia/cuda:12.2.0-devel-ubuntu22.04` provides the CUDA development environment  
- **GPU allocation**: `nvidia.com/gpu: 1` requests a single GPU from the cluster  
- **Runtime**: `gpu_burn 999999` runs for approximately 277 hours (effectively continuous)  
- **Restart policy**: `Never` ensures the pod completes its run without automatic restarts  

Deploy the pod using:
```bash
kubectl apply -f gpu-burn.yaml
```

## Grafana Cloud Integration

### Sharing Dashboards with Remote Teams

While the local Grafana deployment provides comprehensive monitoring capabilities, organizations often need to share dashboards with team members who cannot directly access the internal infrastructure. Grafana Cloud offers an ideal solution by enabling metrics to be pushed from the local Prometheus instance to a cloud-hosted environment, making dashboards accessible to remote teams without requiring VPN or direct network access.

### Prometheus Remote Write Configuration

Grafana Cloud supports Prometheus remote write protocol, allowing local Prometheus to continuously push metrics to the cloud. This approach offers several advantages:

- **No inbound firewall rules required** - Metrics are pushed outbound from the lab
- **Real-time data synchronization** - Metrics appear in Grafana Cloud within seconds
- **Selective metric filtering** - Control which metrics are sent to manage costs
- **Multi-cluster aggregation** - Consolidate metrics from multiple environments

### Setup Overview

The integration involves three main steps:

1. **Configure Grafana Cloud credentials** - Create a Prometheus remote write endpoint and API key in Grafana Cloud
2. **Update Prometheus configuration** - Add remote write settings to the kube-prometheus-stack Helm values
3. **Export and import dashboards** - Transfer dashboard definitions from local Grafana to Grafana Cloud

### Automated Setup Script

An automated setup script simplifies the configuration process:

```bash
./setup-grafana-cloud-remote-write.sh
```

The script prompts for Grafana Cloud credentials and automatically:
- Creates Kubernetes secrets for authentication
- Updates Prometheus with remote write configuration
- Restarts Prometheus to apply changes
- Verifies the setup is working correctly

### Remote Write Configuration Example

The Prometheus remote write configuration adds a new endpoint to push metrics:

```yaml
prometheus:
  prometheusSpec:
    remoteWrite:
      - url: https://prometheus-xxx.grafana.net/api/prom/push
        basicAuth:
          username:
            name: grafana-cloud-credentials
            key: username
          password:
            name: grafana-cloud-credentials
            key: password
        writeRelabelConfigs:
          - sourceLabels: [__name__]
            targetLabel: cluster
            replacement: hpe-lab-cluster
```

### Cost Optimization

Grafana Cloud's free tier includes 10,000 active series, which is sufficient for focused GPU monitoring. To stay within limits, configure metric filtering:

```yaml
writeRelabelConfigs:
  # Only send GPU and critical metrics
  - sourceLabels: [__name__]
    regex: 'DCGM_.*|up|kube_pod_.*'
    action: keep
```

### Dashboard Export and Import

Once metrics are flowing to Grafana Cloud:

1. Export dashboards from local Grafana (Dashboard → Share → Export → Save to file)
2. Import JSON to Grafana Cloud (Dashboards → New → Import)
3. Select the Grafana Cloud Prometheus data source
4. Share dashboard links with team members

For detailed setup instructions, see the [Grafana Cloud Setup Guide](grafana-cloud-setup.md).

