# Grafana Cloud Quick Start

## 🚀 Quick Setup (3 Steps)

### 1. Get Grafana Cloud Credentials
- Sign up at [grafana.com](https://grafana.com) (free tier available)
- Go to: **Connections** → **Add new connection** → **Hosted Prometheus metrics**
- Note down:
  - Remote Write Endpoint: `https://prometheus-xxx.grafana.net/api/prom/push`
  - Instance ID (username)
  - Generate API Key (password)

### 2. Choose Your Setup Method

#### Option A: Prometheus Remote Write (Recommended for existing Prometheus)
Best if you already have Prometheus running and want to keep local queries.

```bash
cd /Users/hongjun/work/grafana-prometheus-hpe-greenlake-com-nvidia
./setup-grafana-cloud-remote-write.sh
```

#### Option B: Grafana Agent (Lightweight alternative)
Best if you want minimal resource usage or starting fresh.

```bash
cd /Users/hongjun/work/grafana-prometheus-hpe-greenlake-com-nvidia
./setup-grafana-agent.sh
```

The script will:
- ✅ Create Kubernetes secret with your credentials
- ✅ Configure Prometheus remote write
- ✅ Restart Prometheus with new configuration
- ✅ Verify the setup

### 3. Export & Import Dashboard
```bash
# Access local Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Open http://localhost:3000 (admin / prom-operator)
# Dashboard → Share → Export → Save to file
# Import the JSON file to Grafana Cloud
```

## 📚 Full Documentation
- **Prometheus Remote Write**: [docs/grafana-cloud-setup.md](docs/grafana-cloud-setup.md)
- **Grafana Agent**: [docs/grafana-agent-setup.md](docs/grafana-agent-setup.md)

## 🤔 Which Option Should I Choose?

| Criteria | Prometheus Remote Write | Grafana Agent |
|----------|------------------------|---------------|
| Already have Prometheus | ✅ **Recommended** | ⚠️ Redundant |
| Need local queries | ✅ Yes | ❌ No |
| Want minimal resources | ⚠️ ~2GB memory | ✅ ~50MB memory |
| Setup complexity | ⚠️ Medium | ✅ Simple |

**For your setup:** Use **Prometheus Remote Write** since you already have kube-prometheus-stack running.

## 🎯 What This Solves
- ✅ Teammates can access GPU monitoring without VPN/lab access
- ✅ Metrics are pushed from your lab to Grafana Cloud
- ✅ Dashboards are shared in the cloud
- ✅ No firewall changes needed

## 📊 After Setup
1. Wait 1-2 minutes for metrics to appear in Grafana Cloud
2. Go to Grafana Cloud → Explore
3. Run query: `up{cluster="hpe-lab-cluster"}`
4. Import your GPU dashboard
5. Share with teammates!
