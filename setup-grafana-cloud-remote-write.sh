#!/bin/bash
# Script to set up Prometheus Remote Write to Grafana Cloud
# Usage: ./setup-grafana-cloud-remote-write.sh

set -e

echo "========================================="
echo "Grafana Cloud Remote Write Setup Script"
echo "========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed or not in PATH${NC}"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo -e "${RED}Error: helm is not installed or not in PATH${NC}"
    exit 1
fi

# Prompt for Grafana Cloud credentials
echo -e "${YELLOW}Please enter your Grafana Cloud details:${NC}"
echo ""
read -p "Grafana Cloud Prometheus Remote Write Endpoint (e.g., https://prometheus-xxx.grafana.net/api/prom/push): " GRAFANA_CLOUD_ENDPOINT
read -p "Grafana Cloud Instance ID / Username (numeric ID): " GRAFANA_CLOUD_USER
read -sp "Grafana Cloud API Key / Password: " GRAFANA_CLOUD_PASSWORD
echo ""
read -p "Cluster identifier label (default: hpe-lab-cluster): " CLUSTER_NAME
CLUSTER_NAME=${CLUSTER_NAME:-hpe-lab-cluster}

echo ""
echo -e "${GREEN}Configuration received!${NC}"
echo "Endpoint: $GRAFANA_CLOUD_ENDPOINT"
echo "Username: $GRAFANA_CLOUD_USER"
echo "Cluster: $CLUSTER_NAME"
echo ""

# Confirm before proceeding
read -p "Do you want to proceed with the setup? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

# Step 1: Create Kubernetes secret
echo ""
echo -e "${YELLOW}Step 1: Creating Kubernetes secret...${NC}"

if kubectl get secret grafana-cloud-credentials -n monitoring &> /dev/null; then
    echo -e "${YELLOW}Secret 'grafana-cloud-credentials' already exists. Deleting it...${NC}"
    kubectl delete secret grafana-cloud-credentials -n monitoring
fi

kubectl create secret generic grafana-cloud-credentials \
  --from-literal=username="${GRAFANA_CLOUD_USER}" \
  --from-literal=password="${GRAFANA_CLOUD_PASSWORD}" \
  -n monitoring

echo -e "${GREEN}✓ Secret created successfully${NC}"

# Step 2: Create Helm values file
echo ""
echo -e "${YELLOW}Step 2: Creating Helm values file...${NC}"

cat > /tmp/prometheus-remote-write-values.yaml <<EOF
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
          # Add cluster label to all metrics
          - sourceLabels: [__name__]
            targetLabel: cluster
            replacement: ${CLUSTER_NAME}
          # Optional: Only send GPU metrics to reduce cardinality
          # Uncomment the following lines to filter only DCGM metrics
          # - sourceLabels: [__name__]
          #   regex: 'DCGM_.*|up|kube_.*'
          #   action: keep
EOF

echo -e "${GREEN}✓ Values file created at /tmp/prometheus-remote-write-values.yaml${NC}"
echo ""
echo "Contents:"
cat /tmp/prometheus-remote-write-values.yaml

# Step 3: Upgrade Prometheus Helm release
echo ""
echo -e "${YELLOW}Step 3: Upgrading Prometheus Helm release...${NC}"

helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f /tmp/prometheus-remote-write-values.yaml \
  --reuse-values

echo -e "${GREEN}✓ Helm release upgraded successfully${NC}"

# Step 4: Wait for Prometheus to restart
echo ""
echo -e "${YELLOW}Step 4: Waiting for Prometheus to restart...${NC}"
sleep 5

kubectl rollout status statefulset/prometheus-kube-prometheus-stack-prometheus -n monitoring --timeout=300s

echo -e "${GREEN}✓ Prometheus restarted successfully${NC}"

# Step 5: Verify configuration
echo ""
echo -e "${YELLOW}Step 5: Verifying configuration...${NC}"
echo ""
echo "Checking Prometheus pods..."
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Check Prometheus logs for any errors:"
echo "   kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus -f"
echo ""
echo "2. Verify remote write is working in Prometheus UI:"
echo "   kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
echo "   Open: http://localhost:9090/config"
echo ""
echo "3. Wait 1-2 minutes, then check Grafana Cloud:"
echo "   - Go to Explore"
echo "   - Select Prometheus data source"
echo "   - Run query: up{cluster=\"${CLUSTER_NAME}\"}"
echo ""
echo "4. Export your GPU dashboard from local Grafana:"
echo "   kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
echo "   Open: http://localhost:3000"
echo ""
echo "5. Import the dashboard to Grafana Cloud"
echo ""
echo -e "${YELLOW}Configuration file saved at: /tmp/prometheus-remote-write-values.yaml${NC}"
echo ""
