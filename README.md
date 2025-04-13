# Homelab Infrastructure

![Homelab Logo](https://img.shields.io/badge/Homelab-Infrastructure-blue)
![License](https://img.shields.io/github/license/jgodson/homelab)

This repository contains the configuration files and documentation for my personal homelab environment. It serves as both a reference for myself and a resource for others interested in setting up similar self-hosted infrastructure.

## Overview

This homelab setup includes various services hosted on a combination of:
- Kubernetes cluster
- Docker containers
- Virtual machines
- Proxmox VE hypervisor platform

The infrastructure is designed to provide a lab environment for experimenting with technology, hosting personal applications, and learning about infrastructure management.

> **Want more details?** Visit [jasongodson.com](https://jasongodson.com) for detailed blog posts and in-depth explanations of my homelab setup.

## Infrastructure Details

### Proxmox Hypervisor Cluster
- 4-node Proxmox cluster with High Availability support
- Ceph distributed storage for high availability and redundancy
- Supports live migration of VMs between nodes
- Hosts all the VMs that make up the rest of the infrastructure

### Kubernetes
- 3 node Kubernetes cluster running as VMs on Proxmox
- MetalLB for load balancing
- Traefik for ingress controller
- Variety of self-hosted applications and services

### Docker
- Multiple standalone Docker hosts for various services
- Organized by use case and data sensitivity

## Repository Structure

```
homelab/
├── docker/              # Docker Compose services configuration
├── docs/                # General documentation
├── k8s-configs/         # Kubernetes manifests and Helm values
├── observability-config/# Monitoring and logging configurations
├── VM/                  # Virtual machine only configurations (not using Docker)
└── website/             # Personal website hosted on the homelab
```

## Services & Applications

### Docker Services

- **AI Tools**: Self-hosted AI tooling
- **Frigate**: NVR with object detection
- **Home Assistant**: Home automation platform
- **Ingress (Local & Public)**: Reverse proxy setups with Caddy
- **MinIO**: S3-compatible object storage

### Kubernetes Applications

- **Monitoring Stack**: Grafana, Prometheus, Loki, InfluxDB
- **MetalLB**: Load balancer for bare-metal Kubernetes
- **Traefik**: Ingress controller for Kubernetes

## Purpose

This repository primarily serves as:

1. **Documentation** - A reference for my configuration and setup details
2. **Backup** - Version-controlled backup of important configs
3. **Knowledge Sharing** - A resource for others interested in similar setups

Rather than being meant for direct cloning and use, the configurations here can be used as examples or starting points. Each deployment is tailored to my specific environment and needs so you will likey see references to my own ip addresses or domains that will not be directly transferrable to your own setup.

## Website

The personal website in this repository is hosted directly on the homelab infrastructure, demonstrating the capability to self-host web applications. It features:

- A clean, responsive design
- Information about my skills and projects
- Links to social profiles
- Build and deployment automation

## Contributing

While this repository primarily serves as documentation for my personal setup, if you find issues or have suggestions, feel free to open an issue or submit a pull request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- The homelab community for inspiration and guidance, especially [TechnoTim](https://github.com/techno-tim) and [JimsGarage](https://github.com/JamesTurland/JimsGarage/tree/main)
- Open source projects that make self-hosting possible