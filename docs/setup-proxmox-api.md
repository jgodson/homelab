# Proxmox API Setup Commands For Automation

Run these commands via SSH on any Proxmox host in the cluster.

## 1. Create custom role with necessary permissions

```bash
pveum role add HomelabAutomation -privs "VM.Audit,VM.Migrate,VM.PowerMgmt,Sys.PowerMgmt,Sys.Audit,Sys.Console"
```

If role already exists, modify it:
```bash
pveum role modify HomelabAutomation -privs "VM.Audit,VM.Migrate,VM.PowerMgmt,Sys.PowerMgmt,Sys.Audit,Sys.Console"
```

## 2. Create API user

```bash
pveum user add homelab-automation@pve --comment "API user for Gitea Actions automation"
```

## 3. Assign role to user at cluster level

```bash
pveum acl modify / -user homelab-automation@pve -role HomelabAutomation
```

## 4. Create API token

**Save the output - it won't be shown again!**

```bash
pveum user token add homelab-automation@pve gitea-workflows --privsep 0
```

## 5. Add to Gitea Secrets

- **PROXMOX_API_USER**: `homelab-automation@pve!gitea-workflows`
- **PROXMOX_API_TOKEN**: `<the token UUID from step 4>`

## Permissions Granted

- **VM.Audit**: View/list VMs and their configurations
- **VM.Migrate**: Migrate VMs between hosts
- **VM.PowerMgmt**: Start/stop/shutdown VMs
- **Sys.PowerMgmt**: Reboot Proxmox hosts
- **Sys.Audit**: Required for cluster-wide operations (HA resources API, cluster status)
- **Sys.Console**: Required for HA management (enabling/disabling HA resources)

**Note**: The `Sys.Console` permission requirement for HA management is unusual but required by Proxmox's permission check on the `/cluster/ha/resources` POST endpoint.

## To delete and recreate token if needed

```bash
pveum user token remove homelab-automation@pve gitea-workflows
pveum user token add homelab-automation@pve gitea-workflows --privsep 0
```
