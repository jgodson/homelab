# Talos Machine Configurations

This directory contains Talos Linux machine configuration files, patches, and related assets for the homelab Kubernetes cluster.

## Structure

- `controlplane-config.yaml` — Full control plane **machine config** (auto-redacted)
  - Complete cluster configuration with secrets removed
  - This is the config applied to control plane nodes
  - Can be merged with real secrets to recreate the cluster
  - Updated by running `sync-configs.sh`
- `worker-config.yaml` — Worker node **machine config** (auto-redacted)
  - Same redaction as controlplane, applied to worker nodes
  - Updated by running `sync-configs.sh --worker` or `sync-configs.sh`
- `sync-configs.sh` — Retrieve and redact current cluster configs
  - Run this whenever you make cluster config changes
  - Keeps the versioned configs in sync with the live cluster
  - `./sync-configs.sh` — sync controlplane and worker configs
  - `./sync-configs.sh --controlplane` — sync controlplane config only
  - `./sync-configs.sh --worker` — sync worker only
- `merge-secrets.sh` — Merge real secrets into redacted template
  - For disaster recovery: creates usable configs from the template
  - Takes a backup config with secrets + template → new config
- `encode-talosconfig.sh` — Encode talosconfig for CI/CD secrets
  - Encodes your **client config** (`~/.talos/config`) for Gitea Actions
  - This is the authentication file used by `talosctl`
  - Different from machine config - this is for client access
- `README.md` — This file

## Cluster Configuration

**Control Plane Nodes**: 192.168.1.30, 192.168.1.31, 192.168.1.32
**Worker Nodes**: 192.168.1.33
**Control Plane VIP**: 192.168.1.250:6443 (ens18 interface)
**CNI**: Cilium (Flannel disabled via `cluster.network.cni.name: none`)
**Kubernetes**: v1.36.2
**Talos**: v1.13.4

The cluster uses a Virtual IP (VIP) for high-availability control plane access. If one control plane goes down, the VIP automatically moves to another healthy node, ensuring kubectl always works.

### Using talosctl with VIP

Your talosconfig should be set to use the VIP endpoint. Common commands:

```bash
# Most commands work fine with VIP endpoint
talosctl version
talosctl get members

# For health checks, specify --nodes with the VIP
talosctl health --nodes 192.168.1.250 --server=false

# Or check the full cluster explicitly
talosctl health \
  --control-plane-nodes 192.168.1.30,192.168.1.31,192.168.1.32 \
  --worker-nodes 192.168.1.33
```

## Syncing Configs

**Run this after making any cluster configuration changes:**

```bash
# Sync both controlplane and worker configs (default)
./sync-configs.sh

# Sync worker config only
./sync-configs.sh --worker

# Sync controlplane config only
./sync-configs.sh --controlplane
```

This will:
1. Retrieve the current machine config from the target node(s)
2. Automatically redact all sensitive data (certificates, keys, tokens, secrets)
3. Save the safe version(s) to `controlplane-config.yaml` / `worker-config.yaml`
4. Ready to commit to GitHub!

The script samples one control plane node and one worker node:

- Control plane sample: `192.168.1.31`
- Worker sample: `192.168.1.33`

The current cluster has three control plane nodes and one worker-only node. If you suspect role or node drift, compare the live configs before trusting a single sampled config:

```bash
talosctl get machineconfig --nodes 192.168.1.30 -o json | jq -r 'select(.metadata.id == "v1alpha1") | .spec' > /tmp/cp1.yaml
talosctl get machineconfig --nodes 192.168.1.31 -o json | jq -r 'select(.metadata.id == "v1alpha1") | .spec' > /tmp/cp2.yaml
talosctl get machineconfig --nodes 192.168.1.32 -o json | jq -r 'select(.metadata.id == "v1alpha1") | .spec' > /tmp/cp3.yaml
talosctl get machineconfig --nodes 192.168.1.33 -o json | jq -r 'select(.metadata.id == "v1alpha1") | .spec' > /tmp/worker.yaml
```

## Upgrading Talos

Upgrade one node at a time. Do not start the next node until Kubernetes and stateful workloads have settled.

Prerequisites:

```bash
brew install kubectl-cnpg
```

Pre-flight checks:

```bash
kubectl get nodes -o wide
kubectl get pods -A | grep -Ev 'Running|Completed'
kubectl get clusters.postgresql.cnpg.io -A \
  -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,PHASE:.status.phase,READY:.status.readyInstances,INSTANCES:.spec.instances,PRIMARY:.status.currentPrimary
talosctl health --nodes 192.168.1.250 --server=false
```

Treat failed one-off Jobs/CronJobs separately from stuck workloads. For example, an old failed synthetic monitoring Job is not a reason to block a node upgrade, but a degraded controller, StatefulSet, or database cluster is.

If the node hosts a CNPG primary, promote a healthy replica first so the primary PDB does not block drain:

```bash
kubectl cnpg promote <CLUSTER_NAME> <REPLICA_POD> -n <NAMESPACE>
```

Wait for the switchover to settle before draining:

```bash
kubectl get clusters.postgresql.cnpg.io -A \
  -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,PHASE:.status.phase,READY:.status.readyInstances,INSTANCES:.spec.instances,PRIMARY:.status.currentPrimary
kubectl cnpg status <CLUSTER_NAME> -n <NAMESPACE>
```

Cordon and drain the node explicitly:

```bash
kubectl cordon <NODE_NAME>
kubectl drain <NODE_NAME> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --timeout=15m
```

Upgrade the drained node. Disable Talos-managed drain because Kubernetes drain has already been handled explicitly:

```bash
talosctl upgrade \
  --nodes <NODE_IP> \
  --drain=false \
  --image ghcr.io/siderolabs/installer:<TALOS_VERSION>
```

Talos may fall back to the legacy upgrade API and still print a drain phase even with `--drain=false`. That is acceptable if the Kubernetes node was already explicitly drained and the command continues through the upgrade.

After each node:

1. Wait for the node to return `Ready` with the expected Talos version.
2. If the node is still `SchedulingDisabled`, keep it cordoned until Cilium, kube-proxy, and control-plane static pods on that node are healthy.
3. Uncordon only after the node network and static pods are stable:
   ```bash
   kubectl uncordon <NODE_NAME>
   ```
4. Wait for workloads to finish rescheduling and image pulls. A node drain can cause several minutes of churn even when the drain succeeds.
5. Verify there are no unexpected non-running pods:
   ```bash
   kubectl get pods -A | grep -Ev 'Running|Completed'
   ```
6. Verify CNPG clusters are healthy and fully replicated before touching another node:
   ```bash
   kubectl get clusters.postgresql.cnpg.io -A \
     -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,PHASE:.status.phase,READY:.status.readyInstances,INSTANCES:.spec.instances,PRIMARY:.status.currentPrimary
   ```
7. For CNPG specifically, confirm the primary has a streaming replica:
   ```bash
   kubectl exec -n postgresql <PRIMARY_POD> -- \
     psql -U postgres -d postgres -tAc "select application_name, state, sync_state, replay_lsn from pg_stat_replication;"
   ```
8. Run Talos health after the node is uncordoned:
   ```bash
   talosctl health --nodes 192.168.1.250 --server=false
   ```

If a stateful workload is degraded, stop the upgrade and recover it before continuing. A successful `talosctl upgrade` only proves the node upgraded; it does not prove the cluster workloads are safe for the next disruption.

After all nodes are upgraded, run `./sync-configs.sh` and review the generated diff before committing. The sync output can be noisy and may include generated comments or endpoint changes; do not commit it blindly.

## Refreshing talosconfig

`~/.talos/config` is the Talos client authentication file. Its admin client certificate expires. Check it with:

```bash
talosctl config info
```

If the certificate is expired, Talos API calls fail with an error similar to:

```text
tls: expired certificate
```

Recover by regenerating a client config from a secure, unredacted control plane machine config backup:

```bash
talosctl gen secrets \
  --from-controlplane-config /path/to/unredacted/controlplane.yaml \
  --output-file /tmp/talos-secrets.yaml \
  --force

cp ~/.talos/config ~/.talos/config.expired-$(date +%Y%m%d%H%M%S)

talosctl gen config cluster-private https://192.168.1.250:6443 \
  --with-secrets /tmp/talos-secrets.yaml \
  --output-types talosconfig \
  --output ~/.talos/config \
  --force

talosctl config endpoint 192.168.1.250
talosctl config node 192.168.1.30 192.168.1.31 192.168.1.32 192.168.1.33
chmod 600 ~/.talos/config
rm -f /tmp/talos-secrets.yaml
```

After refreshing local `~/.talos/config`, update the Gitea `TALOSCONFIG` secret if workflows use Talos:

```bash
./encode-talosconfig.sh
```

## CI/CD Integration (Gitea Actions)

To use Talos commands in Gitea Actions workflows, you need the **client config**:

```bash
./encode-talosconfig.sh
```

This encodes `~/.talos/config` (your client authentication) as base64. Add the output as a Gitea secret named `TALOSCONFIG`.

**Note**: This is different from `controlplane-config.yaml`:
- **Machine config** (`controlplane-config.yaml`): Applied to nodes, defines cluster settings
- **Client config** (`~/.talos/config`): Used by `talosctl` for authentication

## Disaster Recovery

If you need to recreate control plane nodes from scratch:

1. **Merge secrets from a backup** into the redacted template:
   ```bash
   ./merge-secrets.sh /path/to/backup-config.yaml new-controlplane.yaml
   ```

2. **Apply to new nodes**:
   ```bash
   talosctl apply-config --insecure --nodes <NEW_NODE_IP> --file new-controlplane.yaml
   ```

3. All important settings are preserved:
   - ✅ VIP configuration (192.168.1.250)
   - ✅ Network settings
   - ✅ Features (RBAC, KubePrism, etc.)
   - ✅ Cluster identity and secrets

**Important**: Keep a secure backup of a real machine config file with secrets for disaster recovery!

## Security
- The `sync-configs.sh` script automatically redacts:
  - Certificates and private keys
  - Bootstrap tokens
  - Cluster secrets and encryption keys
  - Kubeconfig credentials
- Always run `sync-configs.sh` before committing config changes
- Never manually edit `controlplane-config.yaml` or `worker-config.yaml` — regenerate with the script
