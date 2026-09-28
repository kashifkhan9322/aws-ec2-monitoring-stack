# Architecture — AWS EC2 Infrastructure Monitoring Stack

## Overview

This project implements a centralised monitoring architecture across two AWS EC2 Linux instances within the same Virtual Private Cloud (VPC). One instance acts as the monitoring server and runs the full observability stack; the other is the monitored server and runs Node Exporter to expose Linux system metrics.

---

## EC2 Instances

### Monitoring EC2

Hosts the following components:

| Component | Port | Role |
|-----------|------|------|
| Prometheus | 9090 | Metrics collection, storage, and alerting |
| Grafana | 3000 | Metrics visualisation and dashboarding |
| Alertmanager | 9093 | Alert routing and notification management |

### Monitored EC2

Hosts the following component:

| Component | Port | Role |
|-----------|------|------|
| Node Exporter | 9100 | Exposes Linux system metrics over HTTP |

---

## Data Flow

```
Monitored EC2
└── Node Exporter (:9100)
        │
        │  Linux metrics over TCP 9100
        │  (private network — VPC internal)
        ▼
Monitoring EC2
└── Prometheus (:9090)
        │
        ├──────────────────────┐
        │                      │
        ▼                      ▼
    Grafana (:3000)     Alertmanager (:9093)
    (visualisation)     (alert routing)
```

### Step-by-step

1. **Node Exporter** runs on the monitored EC2 and exposes Linux system metrics (CPU, memory, disk, network, filesystem) at `http://MONITORED_SERVER_PRIVATE_IP:9100/metrics`.

2. **Prometheus** is configured with a scrape job targeting Node Exporter over the VPC private network on port 9100. It scrapes metrics every 15 seconds and stores them in its local time-series database.

3. **Prometheus evaluates alert rules** (defined in `prometheus/rules/node-alerts.yml`) against the collected metrics. If any alert condition is met, Prometheus forwards the alert to Alertmanager.

4. **Alertmanager** receives alerts from Prometheus, deduplicates and groups them, and routes them to configured receivers (email, Slack, etc.).

5. **Grafana** queries Prometheus via the Prometheus data source (`http://localhost:9090`) and renders dashboards and panels using PromQL queries.

---

## Network Architecture

Both EC2 instances reside within the same **AWS VPC**. Communication between Prometheus and Node Exporter uses **private IP addresses**, keeping metrics traffic within the VPC and off the public internet.

```
AWS Cloud
│
└── AWS VPC (private network)
        │
        ├── Monitoring EC2 (private IP: MONITORING_SERVER_PRIVATE_IP)
        │       ├── Prometheus    :9090
        │       ├── Grafana       :3000
        │       └── Alertmanager  :9093
        │
        └── Monitored EC2 (private IP: MONITORED_SERVER_PRIVATE_IP)
                └── Node Exporter :9100
```

---

## AWS Security Groups

### Monitoring EC2 Security Group — Inbound Rules

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 22 | TCP | Your IP | SSH administration |
| 9090 | TCP | Your IP | Prometheus UI |
| 3000 | TCP | Your IP | Grafana UI |
| 9093 | TCP | Your IP | Alertmanager UI |

### Monitored EC2 Security Group — Inbound Rules

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 22 | TCP | Your IP | SSH administration |
| 9100 | TCP | Monitoring EC2 Security Group | Node Exporter metrics endpoint |

> **Important:** Port 9100 on the Monitored EC2 should only accept traffic from the Monitoring EC2 security group (or its private IP). Do not expose port 9100 to `0.0.0.0/0`.

---

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Separate EC2 instances | Isolates monitoring infrastructure from monitored workloads |
| Private IP for scraping | Metrics traffic stays within the VPC; no exposure to internet |
| systemd service management | Ensures components restart automatically on failure or reboot |
| Dedicated `node_exporter` user | Runs Node Exporter with minimal privileges (no root required) |
| Alert rules in separate file | Keeps `prometheus.yml` clean; rules can be version controlled independently |
| Base Alertmanager config | Safe default with no credentials; notification channels added separately |
