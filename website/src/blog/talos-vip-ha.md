---
title: "High Availability Control Plane using Talos VIP"
description: "Adding a Virtual IP to Talos Kubernetes for resilient control plane access"
date: 2025-10-22
tags:
  - kubernetes
  - talos
  - homelab
  - automation
layout: post.njk
---

## The Problem: Single Point of Failure

After a busy weekend developing my Proxmox automated restart workflow (keep an eye out for that post), I discovered a critical issue: my kubectl was hardcoded to a single control plane node. When that node went down during restart of one of the Proxmox nodes, my `kubectl` commands no longer were working, even though I had three control planes running! I was able to set the sever to another node to get it working again, but that's not how I expected or wanted it to work.

While Kubernetes itself was highly available (pods running on other nodes were fine), **I couldn't manage the cluster without manual intervention** because my client tools pointed to a downed node.

## The Solution: Virtual IP (VIP)

Talos Linux has built-in support for Layer 2 Virtual IPs on control plane nodes. A VIP is a floating IP address that automatically moves between healthy control planes. If one node goes down, the VIP instantly fails over to another node—zero downtime for kubectl access.

## Implementation

### Network Setup

**Before:**
- Control planes: 192.168.1.30, 192.168.1.31, 192.168.1.32 (DHCP)
- kubectl → 192.168.1.30:6443 (single point of failure)

**After:**
- Control planes: Same individual IPs (DHCP)
- VIP: 192.168.1.250 (floating between control planes)
- kubectl → 192.168.1.250:6443 (HA!)

### Step 1: Create VIP Patch

Create `talos-vip-patch.yaml`:

```yaml
machine:
  network:
    interfaces:
      - interface: ens18  # Your network interface
        dhcp: true
        vip:
          ip: 192.168.1.250
```

**Key notes:**
- Interface name: Use `talosctl get links -n <node-ip>` to find yours (ens18 for my Proxmox VMs)
- Keep `dhcp: true` - nodes keep their individual IPs
- Choose an unused IP for the VIP

### Step 2: Apply to All Control Planes

```bash
# Apply VIP patch to each control plane
for node in 192.168.1.30 192.168.1.31 192.168.1.32; do
  talosctl patch machineconfig --nodes $node --patch @talos-vip-patch.yaml
done
```

No reboot required! The VIP becomes active immediately.

### Step 3: Test the VIP

```bash
# VIP should respond to pings
ping 192.168.1.250

# Kubernetes API should be accessible
curl -k https://192.168.1.250:6443/version
# Should return: {"kind":"Status",...,"code":401}  # Unauthorized = working!
```

### Step 4: Update Cluster Endpoint

Update all control planes to use the VIP as their cluster endpoint:

```yaml
# cluster-endpoint-patch.yaml
cluster:
  controlPlane:
    endpoint: https://192.168.1.250:6443
```

```bash
# Apply to all control planes
for node in 192.168.1.30 192.168.1.31 192.168.1.32; do
  talosctl patch machineconfig --nodes $node --patch @cluster-endpoint-patch.yaml
done
```

### Step 5: Update kubectl and talosctl

```bash
# Update kubectl config
kubectl config set-cluster your-cluster --server=https://192.168.1.250:6443

# Test it works
kubectl cluster-info
# Should show Kubernetes control plane is running at https://192.168.1.250:6443

# Update talosctl endpoint
talosctl config endpoint 192.168.1.250

# Most commands work fine
talosctl version

# For health checks, specify --nodes as the VIP
talosctl health --nodes 192.168.1.250
```

## Testing Failover

The real test: does it actually fail over?

```bash
# Shutdown one control plane
# Make sure you cordon/drain first if you have things running
talosctl shutdown --nodes 192.168.1.30

# kubectl should still work immediately!
kubectl get nodes
```

**Result:** Instant failover! kubectl continued working with zero downtime.

## CI/CD Integration

I'm using Gitea Actions, but for any CI/CD, you'll need to update your talosconfig secret afterwards:

```bash
# After updating talosctl to use VIP
cat ~/.talos/config | base64
```

Update your actions secret with the value.

Now all your automation workflows benefit from HA control plane access!

## Configuration Management

I created scripts to manage this setup in my [homelab repo](https://github.com/jgodson/homelab/tree/main/talos-configs):

- **`sync-configs.sh`** - Pull current config from cluster, auto-redact secrets
- **`merge-secrets.sh`** - Merge real secrets from another config into redacted template for disaster recovery
- **`encode-talosconfig.sh`** - Encode for CI/CD secrets

This allows me to keep configs version-controlled with secrets safely redacted. That said, always keep another backup of the full config with the secrets!

## Results

### Before VIP
- ❌ Single control plane failure = lost cluster access
- ❌ Manual intervention required to reconnect (change the node/server ip used)
- ❌ Workflow failures during maintenance

### After VIP  
- ✅ Control plane failure = instant transparent failover
- ✅ Zero downtime for kubectl access
- ✅ CI/CD workflows resilient to node failures
- ✅ Safe to restart/maintain individual control planes

## Lessons Learned

1. **HA is more than running multiple nodes** - You need to configure HA client access too
2. **Talos VIP is trivial to set up** - No external load balancer needed
3. **Test your HA!** - My Proxmox testing revealed this gap
4. **VIP works great with DHCP** - No need to change node network config

## What's Next

This VIP setup was the final issue I ran into for my Proxmox automated restart workflow. This workflow allows me to do the following if there is a Talos VM on the Proxmox host:

- Drain and cordon Kubernetes node
- Shutdown Talos VM
- Maintain ability to use `talosctl` and `kubectl` commands
- Safely restart Proxmox host

I'll be blogging about that as a whole as well as a few other hurdles I encountered during development of this workflow, so keep an eye out for some more posts in the coming days.

## Resources

- [Talos VIP Documentation](https://www.talos.dev/v1.9/talos-guides/network/vip/)
- [My talos-configs directory](https://github.com/jgodson/homelab/tree/main/talos-configs)
