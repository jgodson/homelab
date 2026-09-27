# Promtail DaemonSet for Kubernetes logs

Promtail tails the container log files that the kubelet writes under `/var/log/pods` on every node and forwards them to Loki. Deploying it as a DaemonSet ensures every node (including control-plane nodes) streams pod `STDOUT`/`STDERR` to Loki without touching any workloads.

## Prerequisites

1. `monitoring` namespace exists. See `k8s-configs/monitoring/namespace.yaml` if you still need to create it.
2. Loki is already running (see `k8s-configs/monitoring/loki`). The default values point to `http://loki-write.monitoring.svc.cluster.local:3100` and `tenant_id: homelab`.
3. Nodes expose `/var/log` and `/var/lib/docker/containers` (or containerd) in the default locations. The Grafana Helm chart mounts both automatically.

## Install / Upgrade

Save or tweak the bundled values first:

```bash
cd k8s-configs/monitoring/promtail
ls values.yaml  # review & adjust labels/limits if needed
```

Then install or upgrade via Helm:

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm upgrade --install promtail grafana/promtail \
  -n monitoring \
  -f values.yaml
```

Key things in the provided `values.yaml`:
- Sets `clients[0].url` to the in-cluster Loki write service with `tenant_id: homelab`.
- Enables tolerations so the DaemonSet schedules on tainted control-plane nodes.
- Defines two scrape jobs: one for general workloads and one scoped to `kube-system` + `monitoring` namespaces.
- Uses the `cri` pipeline stage so JSON logs from containerd/Docker are parsed automatically.
- Applies opt-out semantics (`promtail.io/scrape: "false"` annotation drops a pod’s logs).

## Validation

1. Verify pods are running everywhere:
   ```bash
   kubectl -n monitoring get daemonset promtail -o wide
   kubectl -n monitoring get pods -l app.kubernetes.io/name=promtail
   ```
2. Tail Promtail logs if ingestion fails:
   ```bash
   kubectl -n monitoring logs daemonset/promtail --tail=100
   ```
3. Confirm Loki now receives Kubernetes streams. Either:
   - Port-forward Loki read service and query directly:
     ```bash
     kubectl -n monitoring port-forward svc/loki-read 3100:3100
     curl -s "http://localhost:3100/loki/api/v1/query?query={namespace=\"default\"}" | jq .
     ```
   - Or open Grafana → Explore → Loki datasource and run `{namespace="default"}`.

If you don’t see logs, double-check that Loki and Promtail agree on TLS/HTTP, tenant ID, and timestamps. You can also push a test log manually using the curl example in `k8s-configs/monitoring/loki/README.md` to isolate Loki issues.

## Tuning ideas

- Adjust resource requests/limits in `values.yaml` if Promtail throttles on busy nodes.
- Add more `relabel_configs` to capture custom pod labels (shop IDs, environments, etc.).
- Wire Promtail into Grafana Agent/Alloy instead by switching the client URL to the Alloy OTLP HTTP endpoint if you want centralized processing.
- Attach a `podSecurityPolicy`/`securityContext` if your cluster has stricter requirements; the chart exposes the knobs in `values.yaml`.
