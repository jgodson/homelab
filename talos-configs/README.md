# Talos Machine Configurations

This directory contains Talos Linux machine configuration files, patches, and related assets for the homelab Kubernetes cluster.

## Structure

- `controlplane-config.yaml` — Full control plane **machine config** (auto-redacted)
  - Complete cluster configuration with secrets removed
  - This is the config applied to control plane nodes
  - Can be merged with real secrets to recreate the cluster
  - Updated by running `sync-configs.sh`
- `sync-configs.sh` — Retrieve and redact current cluster config
  - Run this whenever you make cluster config changes
  - Keeps the versioned config in sync with the live cluster
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
**Control Plane VIP**: 192.168.1.250:6443 (ens18 interface)  
**Kubernetes**: v1.32.2  
**Talos**: v1.9.5

The cluster uses a Virtual IP (VIP) for high-availability control plane access. If one control plane goes down, the VIP automatically moves to another healthy node, ensuring kubectl always works.

### Using talosctl with VIP

Your talosconfig should be set to use the VIP endpoint. Common commands:

```bash
# Most commands work fine with VIP endpoint
talosctl version
talosctl get members

# For health checks, specify --nodes with the VIP
talosctl health --nodes 192.168.1.250 --server=false

# Or check individual nodes explicitly
talosctl health --nodes 192.168.1.30,192.168.1.31,192.168.1.32
```

## Syncing Configs

**Run this after making any cluster configuration changes:**

```bash
./sync-configs.sh
```

This will:
1. Retrieve the current machine config from node 192.168.1.31
2. Automatically redact all sensitive data (certificates, keys, tokens, secrets)
3. Save the safe version to `controlplane-config.yaml`
4. Ready to commit to GitHub!

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
- Never manually edit `controlplane-config.yaml` — regenerate it with the script
