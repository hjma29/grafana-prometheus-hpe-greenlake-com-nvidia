#!/bin/bash
# Script to set up Grafana Alloy to send metrics to Grafana Cloud
# Usage: ./setup-grafana-alloy.sh

set -e

echo "========================================="
echo "Grafana Alloy Setup Script"
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

# Step 1: Add Grafana Helm repository
echo ""
echo -e "${YELLOW}Step 1: Adding Grafana Helm repository...${NC}"
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update

echo -e "${GREEN}✓ Helm repository added${NC}"

# Step 2: Create Kubernetes secret
echo ""
echo -e "${YELLOW}Step 2: Creating Kubernetes secret...${NC}"

if kubectl get secret grafana-cloud-credentials -n monitoring &> /dev/null; then
    echo -e "${YELLOW}Secret 'grafana-cloud-credentials' already exists. Deleting it...${NC}"
    kubectl delete secret grafana-cloud-credentials -n monitoring
fi

kubectl create secret generic grafana-cloud-credentials \
  --from-literal=username="${GRAFANA_CLOUD_USER}" \
  --from-literal=password="${GRAFANA_CLOUD_PASSWORD}" \
  -n monitoring

echo -e "${GREEN}✓ Secret created successfully${NC}"

# Step 3: Create Grafana Alloy values file
echo ""
echo -e "${YELLOW}Step 3: Creating Grafana Alloy values file...${NC}"

cat > /tmp/grafana-alloy-values.yaml <<EOF
agent:
  mode: 'flow'
  configMap:
    content: |
      prometheus.remote_write "grafana_cloud" {
        endpoint {
          url = "${GRAFANA_CLOUD_ENDPOINT}"
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
      
      // Discover DCGM exporter service
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
      
      // Alternatively, federate from existing Prometheus
      // Uncomment this section and comment out the above if you prefer
      // prometheus.scrape "prometheus_federation" {
      //   targets = [{
      //     __address__ = "kube-prometheus-stack-prometheus.monitoring.svc:9090"
      //   }]
      //   
      //   metrics_path = "/federate"
      //   params = {
      //     "match[]" = [
      //       '{__name__=~"DCGM_.*"}',
      //       '{__name__=~"up"}',
      //     ]
      //   }
      //   
      //   forward_to = [prometheus.remote_write.grafana_cloud.receiver]
      //   
      //   clustering {
      //     enabled = true
      //   }
      // }

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
EOF

echo -e "${GREEN}✓ Values file created at /tmp/grafana-alloy-values.yaml${NC}"

# Step 4: Install Grafana Alloy
echo ""
echo -e "${YELLOW}Step 4: Installing Grafana Alloy...${NC}"

helm upgrade --install grafana-alloy grafana/alloy \
  -n monitoring \
  -f /tmp/grafana-alloy-values.yaml \
  --wait

echo -e "${GREEN}✓ Grafana Alloy installed successfully${NC}"

# Step 5: Verify installation
echo ""
echo -e "${YELLOW}Step 5: Verifying installation...${NC}"
sleep 5

echo "Checking Grafana Alloy pods..."
kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Next steps:"
echo ""
echo "1. Check Grafana Alloy logs:"
echo "   kubectl logs -n monitoring -l app.kubernetes.io/name=alloy -f"
echo ""
echo "2. Wait 1-2 minutes, then check Grafana Cloud:"
echo "   - Go to Explore"
echo "   - Select Prometheus data source"
echo "   - Run query: up{cluster=\"${CLUSTER_NAME}\"}"
echo ""
echo "3. Export your GPU dashboard from local Grafana:"
echo "   kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
echo "   Open: http://localhost:3000"
echo ""
echo "4. Import the dashboard to Grafana Cloud"
echo ""
echo -e "${YELLOW}Configuration file saved at: /tmp/grafana-alloy-values.yaml${NC}"
echo ""
echo -e "${YELLOW}To uninstall Grafana Alloy:${NC}"
echo "   helm uninstall grafana-alloy -n monitoring"
echo ""
