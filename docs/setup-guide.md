# Setup Guide — AWS EC2 Infrastructure Monitoring Stack

This guide walks through installing and configuring the full monitoring stack across two AWS EC2 Linux instances.

**Placeholders used in this guide:**

| Placeholder | Replace with |
|------------|-------------|
| `MONITORING_SERVER_PUBLIC_IP` | Public IP of the Monitoring EC2 |
| `MONITORING_SERVER_PRIVATE_IP` | Private IP of the Monitoring EC2 |
| `MONITORED_SERVER_PRIVATE_IP` | Private IP of the Monitored EC2 |

---

## Table of Contents

1. [EC2 Instance Preparation](#1-ec2-instance-preparation)
2. [AWS Security Groups](#2-aws-security-groups)
3. [Install Prometheus](#3-install-prometheus)
4. [Install Node Exporter](#4-install-node-exporter)
5. [Install Grafana](#5-install-grafana)
6. [Install Alertmanager](#6-install-alertmanager)
7. [Configure Prometheus](#7-configure-prometheus)
8. [Configure Alert Rules](#8-configure-alert-rules)
9. [Configure Grafana Data Source](#9-configure-grafana-data-source)
10. [Connectivity Testing](#10-connectivity-testing)
11. [Verification](#11-verification)

---

## 1. EC2 Instance Preparation

### Both EC2 instances

Update system packages on each server:

```bash
sudo apt-get update && sudo apt-get upgrade -y
```

> This guide assumes Amazon Linux 2 / Ubuntu 22.04 LTS or equivalent. Adjust package manager commands (`yum` vs `apt`) as required by your AMI.

---

## 2. AWS Security Groups

### Monitoring EC2 — Inbound Rules

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 22 | TCP | Your IP/32 | SSH |
| 9090 | TCP | Your IP/32 | Prometheus UI |
| 3000 | TCP | Your IP/32 | Grafana UI |
| 9093 | TCP | Your IP/32 | Alertmanager UI |

### Monitored EC2 — Inbound Rules

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 22 | TCP | Your IP/32 | SSH |
| 9100 | TCP | Monitoring EC2 Security Group ID | Node Exporter metrics |

> **Security:** Port 9100 should reference the Monitoring EC2 Security Group as the source — not `0.0.0.0/0`. This restricts Node Exporter access to the Monitoring EC2 only.

---

## 3. Install Prometheus

Run these commands on the **Monitoring EC2**.

### Download and install

```bash
# Check latest release at https://github.com/prometheus/prometheus/releases
PROMETHEUS_VERSION="2.51.0"

cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz

tar xzf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
cd prometheus-${PROMETHEUS_VERSION}.linux-amd64
```

### Create system user and directories

```bash
sudo useradd --no-create-home --shell /bin/false prometheus

sudo mkdir -p /etc/prometheus /var/lib/prometheus
sudo mkdir -p /etc/prometheus/rules

sudo cp prometheus promtool /usr/local/bin/
sudo cp -r consoles console_libraries /etc/prometheus/

sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
sudo chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool
```

### Create systemd service

```bash
sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus
Documentation=https://prometheus.io/docs/introduction/overview/
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus/ \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
```

### Enable and start

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now prometheus
sudo systemctl status prometheus
```

---

## 4. Install Node Exporter

Run these commands on the **Monitored EC2**.

### Download and install

```bash
NODE_EXPORTER_VERSION="1.7.0"

cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz

tar xzf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
sudo cp node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
```

### Create system user

```bash
sudo useradd --no-create-home --shell /bin/false node_exporter
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
```

### Install systemd service

```bash
# Copy the service file from this repository
sudo cp node-exporter/node_exporter.service /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
sudo systemctl status node_exporter
```

### Verify metrics endpoint

```bash
curl http://localhost:9100/metrics
```

You should see a large block of text-based metrics in the Prometheus exposition format.

---

## 5. Install Grafana

Run these commands on the **Monitoring EC2**.

```bash
# Add Grafana APT repository (Ubuntu/Debian)
sudo apt-get install -y software-properties-common
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

sudo apt-get update
sudo apt-get install -y grafana

sudo systemctl daemon-reload
sudo systemctl enable --now grafana-server
sudo systemctl status grafana-server
```

> For Amazon Linux 2 / RHEL-based systems, use the Grafana YUM repository. See [Grafana installation docs](https://grafana.com/docs/grafana/latest/setup-grafana/installation/).

---

## 6. Install Alertmanager

Run these commands on the **Monitoring EC2**.

```bash
ALERTMANAGER_VERSION="0.27.0"

cd /tmp
wget https://github.com/prometheus/alertmanager/releases/download/v${ALERTMANAGER_VERSION}/alertmanager-${ALERTMANAGER_VERSION}.linux-amd64.tar.gz

tar xzf alertmanager-${ALERTMANAGER_VERSION}.linux-amd64.tar.gz
cd alertmanager-${ALERTMANAGER_VERSION}.linux-amd64

sudo useradd --no-create-home --shell /bin/false alertmanager
sudo mkdir -p /etc/alertmanager /var/lib/alertmanager

sudo cp alertmanager amtool /usr/local/bin/
sudo chown alertmanager:alertmanager /usr/local/bin/alertmanager /usr/local/bin/amtool

# Copy the configuration from this repository
sudo cp alertmanager/alertmanager.yml /etc/alertmanager/
sudo chown -R alertmanager:alertmanager /etc/alertmanager /var/lib/alertmanager
```

### Create systemd service

```bash
sudo tee /etc/systemd/system/alertmanager.service > /dev/null <<EOF
[Unit]
Description=Alertmanager
After=network.target

[Service]
User=alertmanager
Group=alertmanager
Type=simple
ExecStart=/usr/local/bin/alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/var/lib/alertmanager/
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now alertmanager
sudo systemctl status alertmanager
```

---

## 7. Configure Prometheus

On the **Monitoring EC2**, deploy the Prometheus configuration from this repository:

```bash
# Edit prometheus.yml — replace MONITORED_SERVER_PRIVATE_IP with the actual private IP
# Example: 10.0.1.45:9100

sudo cp prometheus/prometheus.yml /etc/prometheus/
sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml

# Reload Prometheus to apply the configuration
sudo systemctl reload prometheus
# or restart if reload is not supported:
sudo systemctl restart prometheus
```

---

## 8. Configure Alert Rules

```bash
# Copy alert rules to Prometheus rules directory
sudo cp prometheus/rules/node-alerts.yml /etc/prometheus/rules/
sudo chown prometheus:prometheus /etc/prometheus/rules/node-alerts.yml

# Validate rule syntax before reloading
promtool check rules /etc/prometheus/rules/node-alerts.yml

# Reload Prometheus
sudo systemctl reload prometheus
```

---

## 9. Configure Grafana Data Source

1. Open Grafana: `http://MONITORING_SERVER_PUBLIC_IP:3000`
2. Log in (default: `admin / admin`) and change the password when prompted
3. Go to **Connections → Data Sources → Add new data source**
4. Select **Prometheus**
5. Set URL: `http://localhost:9090`
6. Click **Save & Test**

See `grafana/README.md` for dashboard recommendations and PromQL examples.

---

## 10. Connectivity Testing

From the **Monitoring EC2**, verify that Node Exporter is reachable:

```bash
# HTTP test — should return Prometheus-format metrics
curl http://MONITORED_SERVER_PRIVATE_IP:9100/metrics

# TCP connectivity test
nc -zv MONITORED_SERVER_PRIVATE_IP 9100
```

If either command fails, check:
- AWS Security Group rules on the Monitored EC2 (port 9100 inbound)
- Node Exporter service status on the Monitored EC2
- Private IP address is correct in `prometheus.yml`

---

## 11. Verification

### Check all services are running

```bash
# On Monitoring EC2
sudo systemctl status prometheus grafana-server alertmanager

# On Monitored EC2
sudo systemctl status node_exporter
```

### Check Prometheus targets

1. Open: `http://MONITORING_SERVER_PUBLIC_IP:9090/targets`
2. The `node-exporter` target should show status: **UP**
3. The `prometheus` target should also show: **UP**

### Run the health check script

```bash
# On the Monitoring EC2
chmod +x scripts/health-check.sh
MONITORED_SERVER_PRIVATE_IP=<actual-private-ip> ./scripts/health-check.sh
```

### Check Prometheus alert rules

```bash
# On the Monitoring EC2
curl http://localhost:9090/api/v1/rules
```

Or browse to: `http://MONITORING_SERVER_PUBLIC_IP:9090/alerts`
