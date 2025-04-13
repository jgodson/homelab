# QEMU Guest Agent Setup

## Overview
The QEMU Guest Agent is a helper daemon installed in a guest virtual machine that enables communication between the host (Proxmox) and the guest system. It provides enhanced management capabilities, improves backup consistency, and enables efficient operations like proper shutdowns.

## Key Features

- **Proper Guest Shutdown**: Executes clean shutdown commands directly within the guest OS, avoiding potentially unsafe ACPI power button emulation
- **Filesystem Freeze/Thaw**: Ensures filesystem consistency during snapshots and backups
- **Time Synchronization**: Immediately synchronizes guest time with the host when a VM is resumed from pause or snapshot
- **Host-Guest Communication**: Enables the host to retrieve information about the guest (IP addresses, running processes, etc.)

## Installation

### Debian/Ubuntu Guests

1. Install the QEMU Guest Agent package:
   ```bash
   apt-get install qemu-guest-agent
   ```

2. Verify the service is running:
   ```bash
   systemctl status qemu-guest-agent.service
   ```
   
   You should see `running` status. Note that this is typically a `static` service, so there's no need to explicitly enable it on boot.

## Enabling in Proxmox VE

1. Select the virtual machine in the Proxmox web interface
2. Go to the **Options** tab
3. Find and edit the **QEMU Guest Agent** setting
4. Check the **Use QEMU Guest Agent** option
5. Click **OK** to save the changes

Alternatively, enable it when creating a new VM by checking the **QEMU Guest Agent** option in the VM creation wizard.

## Verification

To verify that the guest agent is working properly:

1. In the Proxmox web interface, select the VM
2. Check the **Summary** tab - you should see additional information like IP addresses
3. Try using guest agent features like shutdown or reboot from the Proxmox interface

## Troubleshooting

- **Agent Not Detected**: Ensure both the guest service is running and the Proxmox option is enabled
- **Missing IP Information**: Some operating systems require additional configuration to expose all network interfaces
- **Snapshot Issues**: Check guest agent logs if filesystem freeze/thaw operations are failing

## References
- [Proxmox VE QEMU Agent Documentation](https://pve.proxmox.com/wiki/Qemu-guest-agent)
- [QEMU Guest Agent Protocol](https://wiki.qemu.org/Features/GuestAgent)