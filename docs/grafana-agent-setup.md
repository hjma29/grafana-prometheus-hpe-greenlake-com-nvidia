# Grafana Agent Setup for GPU Monitoring

## Overview

Grafana Agent is a lightweight, purpose-built telemetry collector designed specifically for sending metrics, logs, and traces to Grafana Cloud. It's more efficient than running a full Prometheus instance with remote write, especially when your primary goal is to send data to Grafana Cloud.

## Grafana Agent vs Prometheus Remote Write

| Feature | Grafana Agent | Prometheus Remote Write |
|---------|---------------|-------------------------|
| Resource Usage | ~50MB memory | ~1-2GB memory |
| Configuration | Simpler, cloud-first | More complex |
| Data Retention | None (streams to cloud) | Local + remote |
| Use Case | Send to Grafana Cloud | Local queries + remote |
| Service Discovery | Kubernetes native | Kubernetes native |
| Setup Complexity | Lower | Higher |

**When to use Grafana Agent:**
- Primary goal is Grafana Cloud integration
- Want to minimize resource usage
- Don't need local Prometheus for querying

**When to use Prometheus Remote Write:**
- Already have Prometheus running (like your setup)
- Need local metric queries
- Want local retention and queries

## Architecture

Since you already have Prometheus running with kube-prometheus-stack, you have two deployment options:

### Option 1: Replace Prometheus Remote Write (Lightweight)
Deploy Grafana Agent to scrape the same targets and send directly to Grafana Cloud. This is more efficient but you lose local Prometheus queries.

### Option 2: Grafana Agent Alongside Prometheus (Recommended for Your Setup)
Keep your existing Prometheus for local queries and deploy Grafana Agent to send a subset of metrics to Grafana Cloud. This gives you the best of both worlds.

## Installation

### Prerequisites
- Kubernetes cluster access
- Grafana Cloud account with credentials
- Helm 3.x

### Step 1: Add Grafana Helm Repository

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

### Step 2: Get Grafana Cloud Credentials

1. Log into [grafana.com](https://grafana.com)
2. Go to **Connections** → **Add new connection** → **Hosted Prometheus metrics**
3. Note down:
   - **Remote Write Endpoint**: `https://prometheus-xxx.grafana.net/api/prom/push`
   - **Username/Instance ID**: (numeric ID)
   - **API Key**: Generate a new API key

### Step 3: Create Kubernetes Secret

```bash
# Replace with your actual credentials
GRAFANA_CLOUD_USER="<your-instance-id>"
GRAFANA_CLOUD_PASSWORD="<your-api-key>"

kubectl create secret generic grafana-cloud-credentials \
  --from-literal=username="${GRAFANA_CLOUD_USER}" \
  --from-literal=password="${GRAFANA_CLOUD_PASSWORD}" \
  -n monitoring
```

### Step 4: Create Grafana Agent Values File

Create `grafana-agent-values.yaml`:

```yaml
agent:
  mode: 'flow'
  configMap:
    content: |
      prometheus.remote_write "grafana_cloud" {
        endpoint {
          url = "https://prometheus-xxx.grafana.net/api/prom/push"
          basic_auth {
            username = env("GRAFANA_CLOUD_USER")
            password = env("GRAFANA_CLOUD_PASSWORD")
          }
        }
      }
      
      // Scrape GPU metrics from DCGM exporter
      prometheus.scrape "dcgm_exporter" {
        targets = discovery.kubernetes.services.targets
        forward_to = [prometheus.remote_write.grafana_cloud.receiver]
        
        clustering {
          enabled = true
        }
      }
      
      // Discover services in gpu-operator namespace
      discovery.kubernetes "services" {
        role = "service"
        namespaces {
          names = ["gpu-operator"]
        }
        selectors {
          role = "service"
          label = "app=nvidia-dcgm-exporter"
        }
      }
      
      // Add cluster label
      prometheus.relabel "add_cluster_label" {
        forward_to = [prometheus.remote_write.grafana_cloud.receiver]
        
        rule {
          target_label = "cluster"
          replacement  = "hpe-lab-cluster"
        }
      }

  extraEnv:
    - name: GRAFANA_CLOUD_USER
      valueFrom:
        secretKeyRef:
          name: grafana-cloud-credentials
          key: username
    - name: GRAFANA_CLOUD_PASSWORD
      valueFrom:
        secretKeyRef:
          name: grafana-cloud-credentials
          key: password

controller:
  type: 'deployment'
  replicas: 1
```

### Step 5: Install Grafana Agent

```bash
helm install grafana-agent grafana/grafana-agent \
  -n monitoring \
  -f grafana-agent-values.yaml
```

### Step 6: Verify Installation

```bash
# Check if Grafana Agent is running
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana-agent

# Check logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana-agent -f

# Should see messages about scraping targets and sending to remote write
```

## Advanced Configuration - Scrape from Prometheus Federation

If you want to leverage your existing Prometheus and just forward metrics through Grafana Agent:

```yaml
prometheus.scrape "prometheus_federation" {
  targets = [{
    __address__ = "kube-prometheus-stack-prometheus.monitoring.svc:9090"
  }]
  
  metrics_path = "/federate"
  params = {
    "match[]" = [
      '{__name__=~"DCGM_.*"}',
      '{__name__=~"up|kube_pod_.*"}',
    ]
  }
  
  forward_to = [prometheus.remote_write.grafana_cloud.receiver]
  
  clustering {
    enabled = true
  }
}
```

This approach:
- ✅ Leverages existing Prometheus service discovery
- ✅ Uses Prometheus's existing scrape configuration
- ✅ Grafana Agent only forwards metrics to cloud
- ✅ Minimal configuration changes

## Monitoring Grafana Agent

Check if metrics are being sent:

```bash
# Port forward to Grafana Agent
kubectl port-forward -n monitoring svc/grafana-agent 12345:12345

# Check metrics
curl http://localhost:12345/metrics | grep agent_wal_samples
```

## Troubleshooting

### Issue: No metrics appearing in Grafana Cloud

**Check:**
1. Verify credentials are correct:
   ```bash
   kubectl get secret grafana-cloud-credentials -n monitoring -o jsonpath='{.data.username}' | base64 -d
   ```

2. Check Grafana Agent logs:
   ```bash
   kubectl logs -n monitoring -l app.kubernetes.io/name=grafana-agent --tail=100
   ```

3. Verify remote write endpoint URL matches your Grafana Cloud URL

### Issue: Authentication errors

**Solution:**
- Regenerate API key in Grafana Cloud
- Update the secret:
  ```bash
  kubectl delete secret grafana-cloud-credentials -n monitoring
  kubectl create secret generic grafana-cloud-credentials \
    --from-literal=username="<new-user>" \
    --from-literal=password="<new-api-key>" \
    -n monitoring
  ```
- Restart Grafana Agent:
  ```bash
  kubectl rollout restart deployment -n monitoring grafana-agent
  ```

## Uninstall

```bash
helm uninstall grafana-agent -n monitoring
kubectl delete secret grafana-cloud-credentials -n monitoring
```

## Comparison with Your Current Setup

### Current Setup (Prometheus + Remote Write):
```
DCGM Exporter → Prometheus → Remote Write → Grafana Cloud
                    ↓
              Local Queries
```

### With Grafana Agent (Option 1 - Direct):
```
DCGM Exporter → Grafana Agent → Grafana Cloud
```

### With Grafana Agent (Option 2 - Federation):
```
DCGM Exporter → Prometheus → Grafana Agent → Grafana Cloud
                    ↓
              Local Queries
```

## Recommendation for Your Setup

Since you already have Prometheus running and likely use it for local queries, I recommend:

**Keep using Prometheus Remote Write** - It's simpler since you already have it configured, and you're already running Prometheus anyway.

**Consider Grafana Agent if:**
- You want to reduce memory usage by removing Prometheus
- You only need cloud-hosted dashboards (no local queries)
- You're starting fresh without existing Prometheus

For your current setup, the shell script using Prometheus remote write (`setup-grafana-cloud-remote-write.sh`) is the most straightforward solution.

## Resources

- [Grafana Agent Documentation](https://grafana.com/docs/agent/latest/)
- [Grafana Agent Kubernetes Deployment](https://grafana.com/docs/agent/latest/flow/get-started/deploy-agent/)
- [Grafana Cloud Getting Started](https://grafana.com/docs/grafana-cloud/quickstart/)
