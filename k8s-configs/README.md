# Kubernetes Configs

This directory contains configuration files for the Kubernetes cluster.

## VM Config (Talos Linux)

For the Talos Linux nodes (Control Plane and Workers), use the following configuration:

- **Count**: 3 VMs
- **OS**: Talos Linux
- **CPU**: 8 Cores
- **RAM**: 16 GB
- **Disk**: 100 GB
    - Use `Cache: Writeback` for best performance on HDD
    - Additionally after creating run `zfs set sync=disabled rpool/data/vm-<vmid>-disk-0`
