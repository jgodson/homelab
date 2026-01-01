---
title: "Automating Proxmox Host Restarts with Gitea Actions"
description: "Building a fully automated workflow to safely restart Proxmox hosts while maintaining Kubernetes cluster availability and the journey of fixing everything that broke along the way."
date: 2025-10-25
tags:
  - kubernetes
  - proxmox
  - automation
  - gitea
  - homelab
  - infrasturcture
layout: post.njk
---

A couple months ago, I received an email from Grafana alerting me to an issue in my homelab (you can read about [how I set up my monitoring and alerting here](/blog/grafana-alerts)):

{% image "./src/assets/images/proxmox-shutdown-dreaded-email.png", "Email alert about Ceph cluster warning", "(min-width: 768px) 500px, 100vw", "500px" %}

This was certainly concerning since Ceph is critical infrastructure in my homelab. After checking the Grafana dashboard, I discovered it was just a warning (phew!):

{% image "./src/assets/images/proxmox-shutdown-grafana-dashboard.png", "Grafana dashboard showing Ceph warning", "(min-width: 768px) 600px, 100vw" %}

It turns out one of my Proxmox nodes had restarted (I never figured out why), and picked up a newer version of Ceph than the other nodes were running:

{% image "./src/assets/images/proxmox-shutdown-ceph-warning.png", "Proxmox Ceph version mismatch warning", "(min-width: 768px) 600px, 100vw" %}

This didn't seem critically urgent, but restarting Proxmox hosts is a significant undertaking when you have multiple VMs running on each host, especially when those VMs are part of a Kubernetes cluster. I'd been planning to build automation for this using [Gitea Actions](/blog/homelab-automation-gitea), but hadn't gotten around to it yet.

(Un?)Luckily, I received daily reminder emails about the Ceph warning state. Fast forward a couple months, and I finally found time to tackle this project. Here's the story of building a fully automated Proxmox restart workflow.

## The Goal

Create a Gitea workflow that can safely restart any Proxmox host while maintaining Kubernetes cluster availability by:

- Cordoning and draining Kubernetes nodes before shutdown
- Migrating VMs to other Proxmox hosts  
- Handling VMs with local disks (which don't have to be migrated)
- Preserving Proxmox HA configurations
- Preventing workflow failures from runner pod evictions
- Doing it all with a single workflow trigger

## Architecture Overview

The final workflow consists of several coordinated jobs:

```
discover-and-validate
    │
    ├──> get-runner-pod-name (detects runner location)
    │
    └──> verify-runner-safety (ensures runner won't be evicted)
              │
              ├──> cordon-kubernetes-nodes
              │     └──> cordon → drain → shutdown k8s VMs
              │
              ├──> migrate-vms
              │     ├──> disable HA (save config)
              │     ├──> migrate regular VMs
              │     └──> output migration log + HA config
              │
              └──> restart-proxmox-host
                    ├──> shutdown local disk VMs
                    ├──> reboot host via API
                    ├──> start k8s VMs
                    └──> start local disk VMs
                          │
                          └──> migrate-vms-back
                                ├──> restore VMs to original host
                                └──> re-enable HA with saved config
                                      │
                                      └──> uncordon-kubernetes-nodes
```

## The Journey: What Worked and What Didn't

Building this workflow was an exercise in discovering edge cases. Here are the major challenges and how I solved them.

{% image "./src/assets/images/proxmox-shutdown-trial-and-error.png", "Multiple workflow runs showing trial and error", "(min-width: 768px) 600px, 100vw", "600px" %}

### Challenge #1: Control Plane High Availability

**The Problem**: During early testing, I discovered my `kubectl` was hardcoded to a single control plane node at `192.168.1.30`. When that node went down during a restart, I completely lost cluster access—even though I had three control planes running!

**The Solution**: I implemented a Talos Virtual IP (VIP) at `192.168.1.250` that floats between healthy control planes. Now when any control plane goes down, the VIP instantly fails over to another node with zero downtime.

For the full story and implementation details, see my post on [High Availability Control Plane with Talos VIP](/blog/talos-vip-ha).

### Challenge #2: Docker Authentication for Custom Runners

**The Problem**: My Gitea Actions runners use custom Docker images hosted in my private Gitea registry. After a runner pod restarted, workflows failed with authentication errors when trying to pull the custom image.

**Why `imagePullSecrets` Didn't Help**: Kubernetes `imagePullSecrets` only help kubelet pull the pod's container images. They don't help when the workflow executor pulls images via the Docker API. The runner uses a Docker-in-Docker (DinD) architecture where the Docker client library reads credentials from `~/.docker/config.json`, which we never created.

**The Solution**: I created a CronJob that runs every hour to inject Docker credentials into all runner pods using `kubectl exec`. This approach is resilient, self-healing, and doesn't block pod startup.

For the complete implementation, see [Solving Docker Registry Authentication for Gitea Actions Runners](/blog/gitea-actions-docker-auth).

### Challenge #3: PostgreSQL Migration After Bitnami Paywall

**The Problem**: During testing, when Kubernetes drained a node and my PostgreSQL pod restarted on another node, it went into `ImagePullBackOff`. I discovered that Broadcom (Bitnami's owner) had moved the Bitnami Docker images to the `bitnamilegacy` org, breaking my database deployment.

**The Solution**: I migrated from the Bitnami PostgreSQL Helm chart to CloudNativePG, a CNCF Sandbox project that provides Kubernetes-native PostgreSQL management with built-in high availability, streaming replication, and point-in-time recovery.

The migration took some troubleshooting (service account token issues, UID mismatches), but resulted in a much better HA setup. For the full migration story, see [Migrating from Bitnami PostgreSQL to CloudNativePG](/blog/cloudnative-pg-migration).

### Challenge #4: Don't Break Your Own Infrastructure

**The Problem**: The workflow successfully cordoned and drained Kubernetes nodes... and in doing so, evicted critical infrastructure it depended on to run!

Specifically, the Traefik ingress controller was evicted during drain. No ingress meant no traffic to Gitea, so runners couldn't communicate with Gitea and the workflow failed.

**The Fix**: Increased Traefik to 2 replicas with pod anti-affinity to ensure one instance stays available during drains. ✅

**Lesson Learned**: When building automation for infrastructure, identify your FULL dependency chain and ensure N+1 redundancy for every critical component. The workflow depends on: Traefik (ingress) → Gitea (CI/CD) → PostgreSQL (database), all need to stay available during node drains.

### Challenge #5: Runner Safety Validation

**The Problem**: How do you prevent a workflow from draining the very node its runner pod is running on? If the runner gets evicted during the drain, the workflow fails and can't complete the restart process.

**The Challenge**: When running `hostname` in a containerized runner (the `homelab-latest` label that uses custom Docker images), it returns the Docker container ID (like `406f0c5049be`), not the actual Kubernetes pod name. Without the real pod name, you can't query Kubernetes to find out which node the runner is on.

**The Solution**: Use a two-step approach with different runner types:

1. **Step 1 - Get the real pod name**: Run using the `host-docker` label, which executes directly on the host instead of in a container. This gives us the actual pod hostname.

2. **Step 2 - Verify safety**: Use that pod name with `kubectl` (running on `homelab-latest` which has kubectl installed) to check which node the runner is on, and abort if it matches the target node.

{% raw %}
```yaml
get-runner-pod-name:
  runs-on: host-docker  # Direct host access = real hostname
  outputs:
    pod_name: ${{ steps.get-pod.outputs.pod_name }}

verify-runner-safety:
  needs: get-runner-pod-name
  runs-on: homelab-latest  # Has kubectl installed
  steps:
    - name: Check runner node placement
      run: |
        POD_NODE=$(kubectl get pod ${{ needs.get-runner-pod-name.outputs.pod_name }} \
          -n gitea -o jsonpath='{.spec.nodeName}')
        
        if [ "$POD_NODE" = "$TARGET_NODE" ]; then
          echo "❌ Runner is on target node! Aborting."
          exit 1
        fi
```
{% endraw %}

### Challenge #6: VM Discovery and Categorization

The workflow needs to handle three types of VMs differently:

1. **Kubernetes VMs**: Must be cordoned, drained, then shutdown via `talosctl`
2. **Local disk VMs**: Don't need to be migrated, can be shutdown and restarted
3. **VMs using Ceph**: Can be quickly migrated to other hosts

I use the Proxmox API to discover VMs and categorize them:

```bash
# Detect Kubernetes VMs by tag
K8S_VMS=$(echo "$ALL_VMS" | jq -c '[.[] | select(.tags // "" | contains("k8s"))]')

# Detect local disk VMs
LOCAL_DISK_VMS=$(curl -s -k -H "Authorization: PVEAPIToken=$PROXMOX_TOKEN" \
  "https://$PROXMOX_HOST:8006/api2/json/nodes/$TARGET_NODE/qemu/$VMID/config" \
  | jq 'any(.data | to_entries[] | select(.key | startswith("scsi") or startswith("virtio") or startswith("ide")) | .value | tostring | startswith("local"))')

# Regular VMs = everything else
REGULAR_VMS=$(echo "$ALL_VMS" | jq -c '[.[] | select(...)]')
```

### Challenge #7: Proxmox HA Management

**The Problem**: Proxmox HA automatically migrates VMs back to their preferred host, even after migrating via API. The workflow needs to temporarily disable HA, then restore it with the original configuration.

**The Solution**: Save the complete HA configuration before migration and restore it afterwards:

```bash
# Before migration: save HA config
HA_RESOURCES=$(curl -s -k -H "Authorization: PVEAPIToken=$TOKEN" \
  "$PROXMOX_API/cluster/ha/resources")

# Disable HA for each VM
curl -X DELETE "$PROXMOX_API/cluster/ha/resources/$SID"

# After migration: restore HA with original settings
for vm in $VMS; do
  curl -X POST "$PROXMOX_API/cluster/ha/resources" \
    -d "sid=$SID" \
    -d "state=$ORIGINAL_STATE" \
    -d "group=$ORIGINAL_GROUP" \
    -d "max_restart=$MAX_RESTART" \
    -d "max_relocate=$MAX_RELOCATE"
done
```

**Learnings**: 
- The HA API requires `Sys.Console` permission to manage HA resources, not particularly clear from the name!
- Always check the response from curl commands. API calls can fail silently if you don't validate the response, leading to workflows that appear to succeed but actually didn't complete critical steps.

### Challenge #8: Polling and Timeouts

**The Approach**: Operations like VM shutdowns, migrations, and host reboots don't complete instantly, they can take anywhere from a few seconds to several minutes. You can't just fire off an API call and assume it worked.

**The Solution**: Always poll with timeout detection. Check the actual status repeatedly until the operation completes or a timeout is reached:

```bash
SUCCESS=false
for i in {1..30}; do
  STATUS=$(curl -s ... | jq -r '.status')
  
  if [ "$STATUS" = "stopped" ]; then
    SUCCESS=true
    break
  fi
  
  sleep 10
done

if [ "$SUCCESS" != "true" ]; then
  echo "❌ Timeout waiting for VM shutdown!"
  exit 1
fi
```

This pattern is critical throughout the workflow:
- **VM shutdowns**: Poll until `qmstatus` reports `stopped`
- **Migrations**: Poll until migration task completes
- **Host reboots**: Poll until the host is back online
- **VM startups**: Poll until VMs are fully running

Without proper polling, you'll either waste time with arbitrary waits or move on before operations complete, leading to cascading failures.

## The Results

After all the troubleshooting and refinement, the workflow now successfully:

✅ Discovers and categorizes all VMs on the target host
✅ Validates runner safety (won't drain its own node)
✅ Cordons and drains Kubernetes nodes gracefully
✅ Shuts down Talos VMs using `talosctl`
✅ Saves and disables Proxmox HA configurations
✅ Migrates regular VMs to other hosts
✅ Shuts down local disk VMs
✅ Reboots the Proxmox host via API
✅ Brings VMs back up in the correct order
✅ Migrates VMs back to their original host
✅ Restores HA configurations
✅ Uncordons Kubernetes nodes

{% image "./src/assets/images/proxmox-shutdown-restarted.png", "Successful Proxmox restart workflow", "(min-width: 768px) 300px, 100vw", "300px" %}

And most importantly, the Ceph warning is finally resolved:

{% image "./src/assets/images/proxmox-shutdown-resolved.png", "Ceph cluster back to healthy state", "(min-width: 768px) 500px, 100vw", "500px" %}

## Key Takeaway

**Test by actually breaking things** - Each challenge was discovered by testing real failure scenarios. Don't assume it works, actually drain nodes, restart things, and see what breaks.

## Required Proxmox Permissions

The API token needs these permissions on `/`:

- `VM.Audit` - Read VM configurations and status
- `VM.PowerMgmt` - Start/stop VMs  
- `VM.Migrate` - Migrate VMs between hosts
- `Sys.PowerMgmt` - Reboot Proxmox hosts via API
- `Sys.Audit` - Read `/cluster/ha/resources` endpoint
- `Sys.Console` - Write to `/cluster/ha/resources` (enable/disable HA)

## What's Next

This workflow has made Proxmox maintenance significantly easier. What used to be a manual, error-prone process is now a single workflow trigger.

Future improvements I'm considering:

- **Dry-run mode** - Preview what the workflow will do without making changes
- **Scheduled maintenance windows** - Automatic rolling restarts of all Proxmox hosts
- **Notifications** - Alerts when restarts start/finish

Building this automation was quite a journey with plenty of trial and error, but I'm really happy with the end result. What used to require careful manual orchestration is now a reliable, repeatable process. The infrastructure improvements discovered along the way have made my entire homelab more resilient.

Have you automated your infrastructure restarts? What challenges did you encounter? Let me know!

---

## Resources

- [Proxmox VE API Documentation](https://pve.proxmox.com/pve-docs/api-viewer/)
- [Talos Linux Documentation](https://www.talos.dev/)
- [Gitea Actions Documentation](https://docs.gitea.com/usage/actions/overview)
- [CloudNativePG](https://cloudnative-pg.io/)
