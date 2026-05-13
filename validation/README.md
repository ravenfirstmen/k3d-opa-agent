# Validation Policies

Gatekeeper `ConstraintTemplate` and `Constraint` resources for testing admission policies on the cluster.

Files in this folder are **not** auto-applied (unlike `manifests/`). Apply them manually after the cluster is up so you can iterate without bouncing the cluster.

## Contents

| File | Purpose |
|---|---|
| `001-policy-required-annotation.yaml` | Requires the annotation `my.test.policy-testing=mytest:value` on `Deployment`s. Bundles a test `netshoot` namespace. |
| `002-netshoot-bad.yaml` | A `Deployment` **without** the required annotation — used to trigger a violation. |

## Prerequisites

Gatekeeper must be running before the constraint CRD can be registered:

```bash
kubectl wait --for=condition=available --timeout=120s \
  -n gatekeeper-system deployment/gatekeeper-controller-manager
```

## Apply / Tear Down

```bash
kubectl apply -f validation/001-policy-required-annotation.yaml
kubectl wait --for=condition=established \
  crd/k8srequiredannotationvalue.constraints.gatekeeper.sh

# Trigger a violation
kubectl apply -f validation/002-netshoot-bad.yaml

# Clean up
kubectl delete -f validation/002-netshoot-bad.yaml
kubectl delete -f validation/001-policy-required-annotation.yaml
```

## Enforcement Modes

Switch via `spec.enforcementAction` on the `Constraint`:

| Value | Admission behavior | Where violations show up |
|---|---|---|
| `deny` | Request is rejected | apiserver error + constraint `status.violations` + metrics |
| `warn` | Request is admitted, warning returned to client | client warning + constraint `status` + metrics |
| `dryrun` | Request is admitted silently | constraint `status.violations` + metrics only |

```yaml
spec:
  enforcementAction: dryrun  # audit-only
```

Audit re-scans every 60 seconds by default, so `dryrun` violations populate shortly after the offending resource is created — they are not evaluated on admission.

## Observing Violations

### 1. Constraint status (kubectl)

```bash
kubectl get k8srequiredannotationvalue require-policy-testing-annotation -o yaml
# look at: status.totalViolations and status.violations[]
```

### 2. Grafana dashboard

Dashboards → **Policy** → **Gatekeeper / OPA** (http://localhost:3000, `admin` / `password`).

Key panels for this workflow:
- **Active Violations** — current count across all constraints
- **Violations by Enforcement Action** — separates `deny` / `warn` / `dryrun`
- **Violations by Constraint** — table per `constraint_kind` + `constraint_name`

### 3. Prometheus

```promql
# Total open violations
sum(gatekeeper_violations)

# By constraint
gatekeeper_violations{constraint_kind="K8sRequiredAnnotationValue"}

# What would deny do if we flipped it on?
sum(gatekeeper_violations{enforcement_action="dryrun"})
```

### 4. Loki (audit log lines)

```logql
{k8s_namespace_name="gatekeeper-system"}
  | json
  | constraint_action=`dryrun`
  | event_type=`violation_audited`
  | kubernetes_labels_control_plane=`audit-controller`
  | line_format "{{.log}}"
```

Swap `constraint_action` to `deny` or `warn` to see other modes.

## Caveats

- The constraint matches `apps/Deployment` only. Pods created by the Deployment's `spec.template` are **not** evaluated by this rule — they would need a separate constraint targeting `Pod`, or a Rego rule that inspects `spec.template.metadata.annotations` for Deployments.
- `excludedNamespaces` skips `kube-system`, `kube-public`, `kube-node-lease`, `gatekeeper-system`, and `monitoring` so the cluster and observability stack can run unhindered.
- Annotation keys with colons (e.g. `my:test:policy-testing`) are rejected by Kubernetes apiserver validation. Use dots and slashes (`my.test/policy-testing`) for real-world keys; the Rego logic does an exact string match either way.
