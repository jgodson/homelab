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
- [Talos Linux](talos-configs/README.md) cluster running as VMs on Proxmox: 3 control plane nodes behind a VIP and 1 worker
- Cilium CNI (replacing Flannel) for NetworkPolicy enforcement
- MetalLB for load balancing and Traefik as the ingress controller
- Ceph CSI (RBD) for persistent volumes backed by the Proxmox Ceph cluster
- CloudNativePG for a shared PostgreSQL cluster
- Gitea with Actions runners for Git hosting, CI/CD, and the container registry

### Docker
- Multiple standalone Docker hosts for various services
- Organized by use case and data sensitivity

## Repository Structure

```
homelab/
├── .githooks/           # Versioned Git hooks (image metadata stripping)
├── docker/              # Docker Compose services configuration
├── docs/                # General documentation
├── k8s-configs/         # Kubernetes manifests and Helm values
├── llm-context/         # Context and prompt templates for AI assistants
├── observability-config/# Promtail setup for non-Kubernetes hosts
├── projects/            # Hardware and microcontroller project configurations
├── scripts/             # Utility scripts (remote builds, issue creation, image metadata)
├── talos-configs/       # Redacted Talos machine configs and sync/recovery scripts
├── VM/                  # Virtual machine only configurations (not using Docker)
└── website/             # Personal website hosted on the homelab
```

## Services & Applications

### Docker Services

- **AI Tools**: Ollama, Open WebUI, n8n, Flowise, and supporting services
- **Frigate**: NVR with object detection, including a MyQ camera bridge and a remote RV camera
- **Home Assistant**: Home automation platform with ESPHome
- **Local Ingress + AdGuard**: Caddy reverse proxy with AdGuard Home for local DNS and ad blocking
- **Public Ingress**: Caddy behind a Cloudflare Tunnel with CrowdSec
- **Media Cloud**: Jellyfin for video and Immich for photo backup
- **MinIO**: S3-compatible object storage for backups and Loki

### Kubernetes Applications

- **Networking**: Cilium, MetalLB, Traefik
- **Storage & Data**: Ceph CSI RBD, CloudNativePG
- **Gitea**: Git hosting, Actions runners, and scheduled backups to MinIO
- **Monitoring Stack**: Prometheus, Grafana (with alerting), Loki, Tempo, Alloy, Promtail, Telegraf, InfluxDB2, Uptime Kuma, and metrics-server

### Virtual Machines

- **Cloudflared**: Standalone Cloudflare Tunnel connector
- **Ubuntu Desktop**: General-purpose desktop VM

### Hardware Projects

- **ESP32**: Version-controlled ESPHome configurations and project notes (such as the pool temperature sensor), with local secrets excluded from Git
- **RV Gateway**: Raspberry Pi camera and Jellyfin proxies over Tailscale

## Purpose

This repository primarily serves as:

1. **Documentation** - A reference for my configuration and setup details
2. **Backup** - Version-controlled backup of important configs
3. **Knowledge Sharing** - A resource for others interested in similar setups

Rather than being meant for direct cloning and use, the configurations here can be used as examples or starting points. Each deployment is tailored to my specific environment and needs so you will likely see references to my own ip addresses or domains that will not be directly transferrable to your own setup.

## Website

The personal website in this repository is hosted directly on the homelab infrastructure, demonstrating the capability to self-host web applications. It features:

- A static site built with Eleventy, including a blog with pre-rendered Mermaid diagrams
- Information about my skills and projects
- Links to social profiles
- A Docker image deployed to the Kubernetes cluster

## Contributing

While this repository primarily serves as documentation for my personal setup, if you find issues or have suggestions, feel free to open an issue or submit a pull request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- The homelab community for inspiration and guidance, especially [TechnoTim](https://github.com/techno-tim) and [JimsGarage](https://github.com/JamesTurland/JimsGarage/tree/main)
- Open source projects that make self-hosting possible
