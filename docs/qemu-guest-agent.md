### What is qemu-guest-agent

The qemu-guest-agent is a helper daemon, which is installed in the guest. It is used to exchange information between the host and guest, and to execute command in the guest.

In Proxmox VE, the qemu-guest-agent is used for mainly three things:

To properly shutdown the guest, instead of relying on ACPI commands or windows policies
To freeze the guest file system when making a backup/snapshot (on windows, use the volume shadow copy service VSS). If the guest agent is enabled and running, it calls guest-fsfreeze-freeze and guest-fsfreeze-thaw to improve consistency.
In the phase when the guest (VM) is resumed after pause (for example after shapshot) it immediately synchronizes its time with the hypervisor using qemu-guest-agent (as first step).

### To enable it

1. Install the agent on the guest

    `apt-get install qemu-guest-agent`

1. Check that the service is running

    `systemctl status qemu-guest-agent.service`

    You should see `running` and likely that it is a `static` service. (So no need to enable it on boot)

1. Enable in Proxmox

    Check `Use QEMU Guest Agent` either when creating the VM or by going to the `Option` tab and enabling it there.