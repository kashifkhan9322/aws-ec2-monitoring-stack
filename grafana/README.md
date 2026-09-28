# Grafana — Dashboard Configuration

## Overview

Grafana is deployed on the **Monitoring EC2** instance and queries **Prometheus** as its data source to visualize Linux system metrics collected by Node Exporter.

- **Grafana Port:** `3000`
- **Access:** `http://MONITORING_SERVER_PUBLIC_IP:3000`
- **Default credentials:** `admin / admin` (change immediately after first login)

---

## Prometheus Data Source Setup

After Grafana is installed and running, configure Prometheus as the data source:

1. Open Grafana in your browser: `http://MONITORING_SERVER_PUBLIC_IP:3000`
2. Log in with your admin credentials
3. Navigate to **Connections → Data Sources → Add new data source**
4. Select **Prometheus**
5. Set the URL to: `http://localhost:9090`
6. Click **Save & Test** — you should see a green confirmation message

> **Note:** Use `localhost:9090` (not the public IP), because Grafana and Prometheus run on the same EC2 instance and communicate locally.

---

## Recommended Dashboards

You can build custom dashboards or import community dashboards from [grafana.com/grafana/dashboards](https://grafana.com/grafana/dashboards).

### Community Dashboard — Node Exporter Full

A widely used pre-built dashboard for Node Exporter metrics:

- Dashboard ID: **1860**
- Import via: **Dashboards → New → Import → Enter ID 1860**

This dashboard includes panels for:

| Panel | Metric |
|-------|--------|
| CPU Usage | `rate(node_cpu_seconds_total[5m])` |
| Memory Usage | `node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes` |
| Disk I/O | `rate(node_disk_read_bytes_total[5m])` |
| Network Traffic | `rate(node_network_receive_bytes_total[5m])` |
| System Load | `node_load1`, `node_load5`, `node_load15` |
| Uptime | `node_time_seconds - node_boot_time_seconds` |

---

## Custom Dashboard Panels

To build your own panels, use these PromQL queries as starting points:

### CPU Usage (%)
```promql
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

### Memory Usage (%)
```promql
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
```

### Disk Usage (%)
```promql
(1 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})) * 100
```

### Network Receive (bytes/sec)
```promql
rate(node_network_receive_bytes_total{device!="lo"}[5m])
```

### Network Transmit (bytes/sec)
```promql
rate(node_network_transmit_bytes_total{device!="lo"}[5m])
```

---

## Dashboard Exports

The `dashboards/` directory is reserved for exported Grafana dashboard JSON files.

To export a dashboard:

1. Open the dashboard in Grafana
2. Click the **Share** icon → **Export** → **Save to file**
3. Place the exported `.json` file in `grafana/dashboards/`

> No dashboard JSON files are included at this time. This directory is a placeholder for future exports.

---

## Security Notes

- Change the default `admin` password immediately after first login
- Consider restricting Grafana access (port 3000) to your IP only via AWS Security Groups
- Do not commit Grafana admin credentials to this repository
