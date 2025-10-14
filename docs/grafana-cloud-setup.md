# Grafana Cloud Integration Guide

## Overview
This guide walks you through configuring your local Prometheus to send metrics to Grafana Cloud, enabling your teammates to access GPU monitoring dashboards without direct lab access.

## Prerequisites
- Grafana Cloud account (free tier available at [grafana.com](https://grafana.com))
- Access to your Kubernetes cluster
- Existing Prometheus installation (kube-prometheus-stack)

## Step 1: Get Grafana Cloud Credentials

1. **Log into Grafana Cloud**
   - Go to [grafana.com](https://grafana.com) and sign in
   - Navigate to your stack

2. **Get Prometheus Remote Write Details**
   - Click on "My Account" or your stack name
   - Go to "Configure" → "Data Sources" → "Prometheus"
   - Or go to: Connections → Add new connection → Hosted Prometheus metrics
   - Find the section "Remote Write Configuration"
   - Note down:
     - **Remote Write Endpoint**: `https://prometheus-xxx.grafana.net/api/prom/push`
     - **Username/Instance ID**: (usually a numeric ID)
     - **Password/API Key**: Click "Generate now" to create an API key

3. **Create API Key for Remote Write**
   - Go to "Access Policies" or "API Keys"
   - Click "Create API Key" or "Generate token"
   - Name it: `prometheus-remote-write`
   - Role: `MetricsPublisher` or `Editor`
   - Copy and save the API key (you won't see it again!)

## Step 2: Create Kubernetes Secret for Grafana Cloud Credentials

Create a secret to store your Grafana Cloud credentials:

```bash
# Replace these values with your actual Grafana Cloud credentials
GRAFANA_CLOUD_USER="<your-instance-id>"      # Usually a numeric ID
GRAFANA_CLOUD_PASSWORD="<your-api-key>"      # The API key you generated

kubectl create secret generic grafana-cloud-credentials \
  --from-literal=username="${GRAFANA_CLOUD_USER}" \
  --from-literal=password="${GRAFANA_CLOUD_PASSWORD}" \
  -n monitoring
```

Verify the secret:
```bash
kubectl get secret grafana-cloud-credentials -n monitoring
```

## Step 3: Update Prometheus Configuration

You need to add `remoteWrite` configuration to your Prometheus. Since you're using kube-prometheus-stack, update the Helm values:

### Option A: Update via Helm Values File

Create a file `prometheus-remote-write-values.yaml`:

```yaml
prometheus:
  prometheusSpec:
    remoteWrite:
      - url: https://prometheus-xxx.grafana.net/api/prom/push  # Replace with your endpoint
        basicAuth:
          username:
            name: grafana-cloud-credentials
            key: username
          password:
            name: grafana-cloud-credentials
            key: password
        queueConfig:
          capacity: 10000
          maxShards: 200
          minShards: 1
          maxSamplesPerSend: 5000
          batchSendDeadline: 5s
          minBackoff: 30ms
          maxBackoff: 100ms
        writeRelabelConfigs:
          # Optional: Add labels to identify the source
          - sourceLabels: [__name__]
            targetLabel: cluster
            replacement: hpe-lab-cluster
```

### Option B: Upgrade Using Helm Command

```bash
# Get your current Helm values
helm get values kube-prometheus-stack -n monitoring > current-values.yaml

# Edit current-values.yaml and add the remoteWrite section under prometheus.prometheusSpec

# Upgrade the release
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f current-values.yaml \
  -f prometheus-remote-write-values.yaml
```

### Complete Command Example

```bash
# Make sure your remote write endpoint is correct!
GRAFANA_CLOUD_ENDPOINT="https://prometheus-xxx.grafana.net/api/prom/push"

cat > prometheus-remote-write-values.yaml <<EOF
prometheus:
  prometheusSpec:
    remoteWrite:
      - url: ${GRAFANA_CLOUD_ENDPOINT}
        basicAuth:
          username:
            name: grafana-cloud-credentials
            key: username
          password:
            name: grafana-cloud-credentials
            key: password
        queueConfig:
          capacity: 10000
          maxShards: 200
          minShards: 1
          maxSamplesPerSend: 5000
          batchSendDeadline: 5s
          minBackoff: 30ms
          maxBackoff: 100ms
        writeRelabelConfigs:
          - sourceLabels: [__name__]
            targetLabel: cluster
            replacement: hpe-lab-cluster
EOF

# Upgrade Prometheus
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f prometheus-remote-write-values.yaml \
  --reuse-values
```

## Step 4: Verify Prometheus Remote Write

1. **Check Prometheus Pod logs:**
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus -f
```

Look for messages about remote write (should NOT see errors about authentication or connection failures).

2. **Check Prometheus UI:**
```bash
# Access Prometheus UI (NodePort 30090 or port-forward)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

Open `http://localhost:9090/config` and verify the `remote_write` section appears.

Open `http://localhost:9090/targets` to see if targets are being scraped.

3. **Check Grafana Cloud:**
- Log into Grafana Cloud
- Go to Explore
- Select your Prometheus data source
- Run a query like: `up{cluster="hpe-lab-cluster"}`
- You should see metrics appearing (may take 1-2 minutes)

## Step 5: Export and Import Dashboards

### Export from Local Grafana

1. Access your local Grafana:
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

2. Open http://localhost:3000
   - Default credentials: admin / prom-operator (unless changed)

3. Navigate to your GPU dashboard

4. Click the Share icon (or Settings gear) → **Export** → **Save to file**
   - This downloads a JSON file

### Import to Grafana Cloud

1. Log into your Grafana Cloud instance

2. Go to **Dashboards** → **New** → **Import**

3. Upload the JSON file or paste the content

4. In the import screen:
   - **Name**: Keep or modify the dashboard name
   - **Folder**: Select a folder or create new one
   - **Prometheus**: Select your Grafana Cloud Prometheus data source

5. Click **Import**

6. Your dashboard should now be visible in Grafana Cloud!

### Important: Update Dashboard Variables (if needed)

If your dashboard uses variables that reference specific clusters or namespaces, you may need to update them:

1. Open the imported dashboard
2. Click the Settings gear icon → **Variables**
3. Update any queries or default values to match your remote write labels
4. Save the dashboard

## Step 6: Share Dashboard with Teammates

1. Open the dashboard in Grafana Cloud

2. Click the **Share** icon → **Share externally**

3. Options:
   - **Share with team members**: Add users to your Grafana Cloud organization
   - **Snapshot**: Create a point-in-time snapshot (limited time)
   - **Public Dashboard**: Make it publicly accessible (use with caution)
   - **Direct Link**: Share the URL directly with team members who have access

## Troubleshooting

### Issue: Metrics not appearing in Grafana Cloud

**Check:**
1. Verify the secret exists:
   ```bash
   kubectl get secret grafana-cloud-credentials -n monitoring
   ```

2. Check Prometheus logs for errors:
   ```bash
   kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus | grep -i remote
   ```

3. Verify the remote write endpoint URL is correct

4. Ensure API key has correct permissions (MetricsPublisher)

### Issue: Authentication errors

**Solution:**
- Regenerate API key in Grafana Cloud
- Update the Kubernetes secret:
  ```bash
  kubectl delete secret grafana-cloud-credentials -n monitoring
  kubectl create secret generic grafana-cloud-credentials \
    --from-literal=username="<new-user>" \
    --from-literal=password="<new-api-key>" \
    -n monitoring
  ```
- Restart Prometheus:
  ```bash
  kubectl rollout restart statefulset -n monitoring prometheus-kube-prometheus-stack-prometheus
  ```

### Issue: High cardinality / Too many metrics

If you're hitting Grafana Cloud limits, filter metrics:

```yaml
prometheus:
  prometheusSpec:
    remoteWrite:
      - url: https://prometheus-xxx.grafana.net/api/prom/push
        writeRelabelConfigs:
          # Only send GPU metrics
          - sourceLabels: [__name__]
            regex: 'DCGM_.*'
            action: keep
          # Drop high-cardinality labels
          - regex: 'pod_uid|container_id'
            action: labeldrop
```

## Cost Considerations

**Grafana Cloud Free Tier** (as of 2024):
- 10,000 series for Prometheus metrics
- 50 GB logs
- 50 GB traces
- 14-day retention

**Tips to stay within limits:**
- Only send necessary metrics (use `writeRelabelConfigs` to filter)
- Monitor your usage in Grafana Cloud dashboard
- Consider sending only GPU-specific metrics (DCGM_*)

## Alternative: Prometheus Federation (Advanced)

If you prefer not to use remote write, you can set up Prometheus federation where Grafana Cloud periodically scrapes your local Prometheus. However, this requires exposing your Prometheus with proper authentication, which is more complex when external access is restricted.

## Next Steps

1. ✅ Set up remote write to Grafana Cloud
2. ✅ Export and import your GPU dashboards
3. ✅ Share dashboards with teammates
4. 📊 Create alerts in Grafana Cloud for GPU metrics
5. 📧 Set up notification channels (Slack, Email, PagerDuty)

## References

- [Grafana Cloud Documentation](https://grafana.com/docs/grafana-cloud/)
- [Prometheus Remote Write](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#remote_write)
- [kube-prometheus-stack Helm Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
