# Telegraf SSH VM Disk Monitoring

Monitor virtual machines and get **real disk usage metrics** using Telegraf with SSH-based collection directly from VMs.

## VM Inventory via ConfigMap

The VM list must be supplied via a mounted file and referenced by the `VM_LIST_FILE` environment variable.

Current default in `values.yaml`:

```
VM_LIST_FILE=/config/vms/hosts
```

The Helm values add a volume mount from the `telegraf-vm-hosts` ConfigMap at `/config/vms` so the script reads `/config/vms/hosts`.

Edit `telegraf-vm-hosts-configmap.yaml` to update the list. Format:

```
name:ip
# Comments and blank lines are ignored
```

After modifying the ConfigMap, apply it and restart (or let the volume projection update) for Telegraf to pick up changes:

```
kubectl apply -f telegraf-vm-hosts-configmap.yaml
kubectl rollout restart deploy/telegraf-ssh -n monitoring
```

## Failure Behavior

If the VM list file is missing or empty **no fake disk metrics are emitted**. Instead only status objects appear:

Scenarios:

| Condition | Status Objects |
|-----------|----------------|
| Missing SSH binary | start, missing (error_reason=ssh_missing) |
| Missing SSH key | start, missing (error_reason=key_missing) |
| VM list file absent | start, missing (error_reason=vm_list_missing) |
| VM list file empty | start, missing (error_reason=vm_list_empty) |
| Hosts present but all failed | start, per-host failures (success=0), end (success=0), none_succeeded |

InfluxDB will therefore contain only `vm_collection_status` entries for these failure cycles; dashboards can alert on `stage="missing"` or `stage="none_succeeded"`.

## Security Notes

You can instead store hosts in a Secret if you consider the content sensitive. In that case:
1. Create a Secret with key `hosts`.
2. Replace the `vm-hosts` volume definition in `values.yaml` from `configMap:` to `secret:`.
3. Keep the same mountPath and `VM_LIST_FILE` environment variable.

## Updating Hosts

To add/remove VMs, edit the ConfigMap and re-apply. No image rebuild needed.

## Example Query (InfluxQL or Flux)

Filter by tag `vm_name` or `vm_ip` on measurement `vm_disk_usage` to graph capacity.

## Overview

This deployment uses the [official InfluxData Telegraf Helm chart](https://artifacthub.io/packages/helm/influxdata/telegraf) with a custom SSH-based collection script to get **actual filesystem usage** from VMs.

**Key Features:**
- ✅ **Real disk usage** (not just allocation) via SSH + `df` command
- ✅ **Simple and reliable** - no API tokens or guest agents needed  
- ✅ **Automatic collection** every 60 seconds
- ✅ **Integration** with existing InfluxDB2
- ✅ **Dedicated telegraf user** for secure SSH access
- ✅ **Kubernetes deployment** with proper security contexts

## Architecture

```
VMs ← SSH calls ← Telegraf Pod (script) → InfluxDB2
```

## Setup Instructions

### 1. Setup SSH Access for Telegraf

**Option A: Automated Setup (Recommended)**

Use Ansible to create a dedicated `telegraf` user and SSH keys on all VMs:
- ✅ Dedicated `telegraf` user on each VM
- ✅ SSH key pair for secure authentication
- ✅ Passwordless SSH access between VMs
- ✅ Test scripts for verification

**Option B: Manual Setup**

If you prefer manual setup, create a `telegraf` user on each VM and configure SSH keys manually.

### 2. Update VM List

Edit `telegraf-vm-hosts-configmap.yaml` to add your VMs:

```yaml
# Format: vm-name:vm-ip (one per line)
# Comments and blank lines are ignored
data:
  hosts: |
    vm-name-1:192.168.1.10
    vm-name-2:192.168.1.11
    # Add your VMs here...
```

### 3. Deploy Telegraf

Use the automated deployment script:

```bash
# Deploy SSH-based monitoring
./deploy-ssh-monitoring.sh

# Check logs to verify collection
kubectl logs -n monitoring -l app.kubernetes.io/name=telegraf-ssh --tail=50

# Test the collection script manually
kubectl exec -n monitoring deployment/telegraf -- /scripts/collect-vm-disk-usage.sh
```

### 4. Import Grafana Dashboard

1. Open Grafana web interface
2. Go to **Dashboards** → **Import**  
3. Upload `grafana-dashboard.json`
4. Configure data source: **InfluxDB** (your existing connection)
5. Set variables: **bucket=proxmox**

## Configuration Details

### Helm Values

The deployment uses the official Telegraf Helm chart defaults with Proxmox-specific overrides:

- **Official Chart Defaults**: Image, resources, security contexts provided by chart
- **`values.yaml`**: Only Proxmox-specific configuration (config, secrets, monitoring settings)

### Collected Metrics

## Data Collected

The SSH collection script gathers:

### **Disk Metrics** (`vm_disk_usage` measurement):
- `total_bytes`: Total filesystem size in bytes
- `used_bytes`: Used space in bytes  
- `free_bytes`: Available space in bytes
- `used_percentage`: Percentage of disk used
- **Tags**: `vm_name`, `vm_ip`, `device`, `fstype`, `mountpoint`

### **Collection Status** (`vm_collection_status` measurement):
- `success`: 1 for successful collections, 0 for failures
- `installed`: 1 if SSH client was installed at runtime, 0 if pre-existing
- **Tags**: `stage` (start/vm/end/missing/none_succeeded), `vm_name`, `vm_ip`, `error_reason`
- **Purpose**: Track collection health and diagnose SSH or configuration issues

### InfluxDB Integration

Metrics are sent to:
- **URL**: `http://influxdb-influxdb2.monitoring.svc.cluster.local:8086`
- **Bucket**: `proxmox` (configurable)
- **Organization**: From secret `telegraf-influxdb-credentials`
- **Token**: From secret `telegraf-influxdb-credentials`

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=telegraf
```

### View Logs
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=telegraf -f
```

### Test SSH Access
```bash
# Test the collection script manually
kubectl exec -n monitoring deployment/telegraf -- /scripts/collect-vm-disk-usage.sh

# Test SSH from Telegraf pod to a specific VM
kubectl exec -n monitoring deployment/telegraf -- ssh -i /ssh/id_rsa telegraf@192.168.1.10 'df -h /'
```

### Verify InfluxDB Data
1. Open InfluxDB2 web interface
2. Go to **Data Explorer** 
3. Select bucket: **proxmox**
4. Query: `from(bucket: "proxmox") |> range(start: -1h) |> filter(fn: (r) => r["_measurement"] == "vm_disk_usage")`
5. Check for both `vm_disk_usage` and `vm_collection_status` measurements

### Common Issues

1. **"Connection refused" SSH errors**: Check SSH keys and telegraf user setup on target VMs
2. **"Permission denied"**: Verify SSH key permissions and telegraf user exists on all VMs
3. **"No data in InfluxDB"**: Check InfluxDB token and organization name in secrets
4. **"Script not found"**: Ensure `telegraf-scripts` ConfigMap is mounted correctly
5. **"SSH missing" status**: Pod requires SSH client; check if runtime install succeeded
6. **Empty VM list**: Verify `telegraf-vm-hosts` ConfigMap exists and has valid entries

### Manual Testing

```bash
# Test SSH setup from Telegraf pod to VMs
kubectl exec -n monitoring deployment/telegraf-ssh -- ssh -i /ssh/id_rsa telegraf@192.168.1.10 'df -h / && hostname'

# Test the collection script manually from pod
kubectl exec -n monitoring deployment/telegraf-ssh -- /scripts/collect-vm-disk-usage.sh

# Check SSH key is mounted
kubectl exec -n monitoring deployment/telegraf-ssh -- ls -la /ssh/

# Verify VM hosts file is mounted  
kubectl exec -n monitoring deployment/telegraf-ssh -- cat /config/vms/hosts
```

## Monitoring

### Alerts

The Grafana dashboard includes panels for:
- High disk usage (>80%)
- Collection status monitoring (success/failure rates)
- VM availability (SSH connectivity)
- SSH installation issues

### Scaling

To monitor additional VMs:
1. Add entries to `telegraf-vm-hosts-configmap.yaml`
2. Re-apply the ConfigMap: `kubectl apply -f telegraf-vm-hosts-configmap.yaml`
3. Restart Telegraf: `kubectl rollout restart deploy/telegraf-ssh -n monitoring`

## Updates

To update the deployment:

```bash
# Update Helm repository
helm repo update influxdata

# Upgrade deployment  
./deploy.sh
```

## Security

- Uses non-root containers with minimal privileges
- SSH key-based authentication (no passwords)
- Dedicated `telegraf` user on VMs with minimal permissions
- Secrets stored in Kubernetes (recommend 1Password integration)
- Internal cluster networking only

## Configuration Options

### Telegraf Settings

Edit `values.yaml` to customize:

- **Collection interval**: Change `agent.interval` (default: 60s)
- **Resource limits**: Modify `resources` section
- **SSH timeout**: Adjust `SSH_CONNECT_TIMEOUT` environment variable
- **Security settings**: Adjust `securityContext` and `podSecurityContext`

### SSH Configuration

Key settings in the script and values:

- **SSH User**: `telegraf` (hardcoded for security)
- **SSH Key Path**: `/ssh/id_rsa` (mounted from secret)
- **Connection Timeout**: 5 seconds (configurable via `SSH_CONNECT_TIMEOUT`)
- **VM List Path**: `/config/vms/hosts` (configurable via `VM_LIST_FILE`)

## Advanced Configuration

### Multiple Environments

To monitor VMs in different environments, create separate deployments:

```bash
# Production VMs
helm install telegraf-prod influxdata/telegraf \
  -f values.yaml \
  --set config.global_tags.environment="production" \
  --set-file config.inputs[0].exec.data_format="json" \
  -n monitoring

# Staging VMs
helm install telegraf-staging influxdata/telegraf \
  -f values.yaml \
  --set config.global_tags.environment="staging" \
  -n monitoring
```

### Custom Tags

Add custom tags to all metrics by modifying `values.yaml`:

```yaml
config:
  global_tags:
    location: "homelab"
    environment: "production"
    cluster: "main"
    collector: "ssh"  # Distinguish from other collection methods
```

## Verification

### 1. Check Pod Status

```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=telegraf-ssh
kubectl logs -n monitoring -l app.kubernetes.io/name=telegraf-ssh
```

### 2. Test SSH Connectivity

```bash
# Test from within the pod
kubectl exec -n monitoring deployment/telegraf-ssh -- \
  ssh -i /ssh/id_rsa -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
  telegraf@192.168.1.10 'df -h / && hostname'
```

### 3. Verify Data in InfluxDB2

1. Open InfluxDB2: `https://influxdb.home.jasongodson.com`
2. Go to **Data Explorer**
3. Select the `proxmox` bucket
4. Look for the `proxmox` measurement
5. You should see metrics with tags like `vm_name`, `vm_id`, etc.

## Metrics Collected

The Proxmox plugin collects these key metrics for each VM:

- **Disk Usage**: `disk_used`, `disk_total`, `disk_free`, `disk_used_percentage`
- **Memory**: `mem_used`, `mem_total`, `mem_free`, `mem_used_percentage`
- **Swap**: `swap_used`, `swap_total`, `swap_free`, `swap_used_percentage`
- **CPU**: `cpuload`
- **Status**: `status` (running/stopped), `uptime`

Tags include: `vm_name`, `vm_id`, `vm_type` (lxc/qemu), `vm_fqdn`, `node_fqdn`

## Troubleshooting

### Common Issues

1. **Pod CrashLoopBackOff**:
   ```bash
   kubectl logs -n monitoring deployment/telegraf-proxmox
   # Check for configuration errors or missing secrets
   ```

2. **Network connectivity**:
   ```bash
   kubectl exec -n monitoring deployment/telegraf-proxmox -- ping your-proxmox-ip
   kubectl exec -n monitoring deployment/telegraf-proxmox -- nslookup your-proxmox-hostname
   ```

3. **API authentication**:
   ```bash
   kubectl exec -n monitoring deployment/telegraf-proxmox -- env | grep PROXMOX
   # Verify the API token format and permissions
   ```

4. **InfluxDB connectivity**:
   ```bash
   kubectl exec -n monitoring deployment/telegraf-proxmox -- \
     nslookup influxdb.monitoring.svc.cluster.local
   ```

### Debug Commands

```bash
# Check secret values
kubectl get secret telegraf-proxmox-credentials -n monitoring -o yaml

# Check configmap
kubectl get configmap telegraf-proxmox-config -n monitoring -o yaml

# Get detailed pod info
kubectl describe pod -n monitoring -l app=telegraf-proxmox

# Follow logs in real-time
kubectl logs -n monitoring -l app=telegraf-proxmox -f
```

## Integration with Existing Monitoring

This Telegraf deployment integrates seamlessly with your existing monitoring stack:

- **Metrics**: Stored in your existing InfluxDB2 `proxmox` bucket
- **Visualization**: Can be displayed in your existing Grafana instance
- **Alerting**: Can be configured in Grafana for disk usage thresholds
- **Service Discovery**: Optionally monitored by Prometheus via ServiceMonitor

## Security Considerations

- Secrets are stored in Kubernetes secrets (not in ConfigMaps)
- Pod runs with non-root user and restricted security context
- API tokens use privilege separation in Proxmox
- Minimal required permissions (PVEAuditor role only)
- TLS verification can be enabled if you have proper certificates

## Scaling and High Availability

For production deployments, consider:

- Running multiple replicas for availability
- Using anti-affinity rules to spread across nodes  
- Implementing proper monitoring and alerting for the Telegraf pods
- Regular backup of configuration and secrets