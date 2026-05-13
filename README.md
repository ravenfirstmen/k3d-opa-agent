# k3d-opa-agent

A local [k3d](https://k3d.io/) cluster pre-configured with [OPA Gatekeeper](https://open-policy-agent.github.io/gatekeeper/) and a full observability stack.

## Stack

| Component | Role |
|---|---|
| [OPA Gatekeeper](https://open-policy-agent.github.io/gatekeeper/) | Policy enforcement (admission controller) |
| [Prometheus](https://prometheus.io/) (kube-prometheus-stack) | Metrics collection and alerting |
| [Grafana](https://grafana.com/) | Dashboards and data exploration |
| [Loki](https://grafana.com/oss/loki/) | Log aggregation |
| [Tempo](https://grafana.com/oss/tempo/) | Distributed tracing |
| [Fluent-bit](https://fluentbit.io/) | Log collection and routing |
| [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/) | OTLP receiver and trace forwarding |

## Requirements

- [k3d](https://k3d.io/) (k3s in Docker)
- [Docker](https://www.docker.com/)
- `uuidgen` (for machine-id generation, required by Fluent-bit)

## Usage

```bash
# Create and start the cluster
./start-cluster.sh

# Tear down the cluster and clean up local volumes
./stop-cluster.sh
```

An optional cluster name can be passed as the first argument (default: `opa-agent`):

```bash
./start-cluster.sh my-cluster
./stop-cluster.sh my-cluster
```

## Endpoints

Once the cluster is running, the following services are accessible on `localhost`:

| Service | URL | Credentials |
|---|---|---|
| Grafana | http://localhost:3000 | `admin` / `password` |
| Prometheus | http://localhost:9090 | — |
| Loki (gateway) | http://localhost:3100 | — |
| OTel Collector (HTTP/OTLP) | http://localhost:4318 | — |

## Architecture

All Helm charts are deployed using k3s's built-in `HelmChart` CRD. The `manifests/` directory is mounted into the k3s server at startup, and k3s automatically installs or upgrades the Helm releases — no Helm CLI or `kubectl apply` is needed after cluster creation.

