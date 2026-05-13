# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A local k3d (k3s-in-Docker) cluster pre-loaded with OPA Gatekeeper and a full observability stack: Prometheus, Grafana, Loki, Tempo, Fluent-bit, and OpenTelemetry Collector.

## Cluster Management

```bash
# Start cluster (default name: "opa-agent")
./start-cluster.sh [cluster-name]

# Stop cluster and clean up .volume/
./stop-cluster.sh [cluster-name]
```

`start-cluster.sh` generates a `machine-id` file (required for Fluent-bit) and mounts `./manifests/` into the k3s server's auto-deploy path (`/var/lib/rancher/k3s/server/manifests/custom`). Any YAML dropped in `manifests/` is automatically applied by k3s on startup.

## Architecture

All components are deployed via k3s's built-in `HelmChart` CRD (`helm.cattle.io/v1`). The k3s server watches the mounted manifests directory and installs/upgrades Helm releases automatically — there is no Helm CLI usage, no `kubectl apply` needed after cluster creation.

### Component Map

| Component | Namespace | Purpose |
|---|---|---|
| OPA Gatekeeper | `gatekeeper-system` | Policy enforcement |
| Prometheus (kube-prometheus-stack) | `monitoring` | Metrics (Grafana disabled in this chart; deployed separately) |
| Grafana | `monitoring` | Dashboards — `admin/password` at `localhost:3000` |
| Loki (SingleBinary) | `monitoring` | Log aggregation at `localhost:3100` |
| Tempo | `monitoring` | Distributed tracing |
| Fluent-bit | `monitoring` | Log collector (tail, k8s events, HTTP inputs) |
| OpenTelemetry Collector | `monitoring` | OTLP receiver + trace forwarder to Tempo |
| Traefik | `kube-system` | Ingress controller (k3s built-in, reconfigured via `HelmChartConfig`) |
| netshoot | default | Network debugging pod |

### Port Mappings (host → cluster loadbalancer)

| Host Port | Service |
|---|---|
| 9090 | Prometheus |
| 3000 | Grafana |
| 3100 | Loki gateway |
| 4318 | OTel Collector HTTP (internal: 4320) |
| 4566 | Available |

### Grafana Datasource Wiring

Grafana is pre-configured with three datasources and correlations:
- **Prometheus** (default) — `http://prometheus-operated.monitoring.svc.cluster.local:9090`
- **Loki** — `http://loki-gateway.monitoring.svc.cluster.local:3100` with a derived field linking `traceid` labels to Tempo
- **Tempo** — `http://tempo.monitoring.svc.cluster.local:3100` with trace-to-logs (Loki) and trace-to-metrics (Prometheus) correlations

### Fluent-bit Pipeline

Fluent-bit collects from four sources (container logs via `tail`, Fluent-bit's own logs, host `/var/log/messages`, and k8s events) plus HTTP inputs on ports 9045/9046. Logs are tagged and routed to Loki. OTel-formatted logs are identified via `rewrite_tag` and forwarded to the OTel Collector on port 8007 (`fluentforward` protocol). A `labelmap.conf` maps `kubernetes.namespace_name` → `k8s_namespace_name`.
