# 🤖 LLM Context - Jason's Homelab

**Purpose:** Complete context for AI assistants to understand the homelab setup efficiently.

## 🏗️ Infrastructure Stack

**Core Platform:**
- **Hypervisor:** Proxmox VE cluster with HA and Ceph storage; everything else runs as VMs on it
- **Kubernetes:** Talos Linux VMs, 3 control plane nodes behind a VIP (`192.168.1.250:6443`) + 1 worker. See `talos-configs/README.md` for current versions
- **Docker:** Standalone Docker Compose hosts, one VM per use case (Home Assistant, Frigate, ingress, MinIO, media, AI tools)
- **Storage:** Ceph RBD (via Ceph CSI) for Kubernetes persistent volumes; MinIO for S3 backups and Loki
- **Networking:** Cilium CNI (Flannel disabled), MetalLB load balancer, Traefik ingress
- **DNS:** AdGuard Home; local domain `*.home.jasongodson.com`

**Key Technologies:**
- **Monitoring:** Prometheus, Grafana (with alerting), Loki, Tempo, Alloy, Promtail, Telegraf, InfluxDB2, Uptime Kuma
- **Database:** CloudNativePG PostgreSQL cluster (shared, external to apps)
- **Git/CI:** Gitea with Actions runners
- **Container Registry:** Integrated with Gitea
- **Secrets:** 1Password as the source of truth for sensitive data

## 📁 Repository Structure

```
homelab/
├── .githooks/           # Versioned hooks (strips image metadata before commit)
├── docker/              # Docker Compose services, one folder per host
│   ├── ai-tools/        # Ollama, Open WebUI, n8n, Flowise
│   ├── frigate/         # NVR + MyQ camera bridge
│   ├── home-assistant/  # Home Assistant + ESPHome (see its AGENTS.md)
│   ├── ingress-local+adguard/ # Caddy (LAN) + AdGuard Home
│   ├── ingress-public/  # Caddy + Cloudflare Tunnel + CrowdSec
│   ├── media-cloud/     # Jellyfin + Immich
│   └── minio/           # S3-compatible object storage
├── docs/                # General how-to notes (Proxmox API, guest agent, DNS)
├── k8s-configs/         # Kubernetes deployments
│   ├── ceph-csi-rbd/    # Persistent volume provisioner
│   ├── cilium/          # CNI
│   ├── cnpg-system/     # CloudNativePG cluster + scheduled backups
│   ├── gitea/           # Git service, Actions runners, backup CronJob
│   ├── metallb/         # Load balancer
│   ├── monitoring/      # Observability stack (Makefile + one folder per service)
│   └── traefik/         # Ingress controller
├── llm-context/         # This folder - AI context
├── observability-config/# Promtail setup for non-Kubernetes hosts
├── projects/            # Hardware projects (ESP32/ESPHome, RV Raspberry Pi gateway)
├── scripts/             # Global automation scripts
├── talos-configs/       # Redacted Talos machine configs + sync/merge scripts
├── VM/                  # VMs configured without Docker (cloudflared, Ubuntu desktop)
└── website/             # Eleventy site/blog, deployed to Kubernetes
```

## 📋 Helm Chart Standards

### Typical Files per Service
- `default-values.yaml` - Copy of original chart defaults (reference)
- `values.yaml` - **ONLY** customizations from defaults (a second chart in the same folder uses `<chart>-values.yaml`, e.g. `gitea/actions-runner-values.yaml`)
- `namespace.yaml` - Namespace definition + any policies
- `setup-*.sh` / `deploy*.sh` - Deployment automation scripts, where needed
- `README.md` - Install steps and recovery notes

Not every service has all of these; match whatever the neighbouring files in that folder use.

### Philosophy
- **Minimal values.yaml:** Only override what you need to change
- **Keep defaults visible:** `default-values.yaml` for reference
- **Scriptable:** Setup scripts or Makefile targets for consistent deployment

## 🔧 Current Active Services

**Kubernetes:**
- **Gitea:** https://gitea.home.jasongodson.com (Git + Actions, 2 runner replicas, backups to MinIO)
- **Monitoring:** Grafana dashboards + alerting over the stack listed above
- **PostgreSQL:** CloudNativePG shared cluster
- **Traefik:** Ingress, exposed via MetalLB LoadBalancer IP
- **Website:** Personal site/blog

**Docker hosts:**
- **Home Assistant + ESPHome:** Home automation, including ESP32 sensors from `projects/esp32/`
- **Frigate:** NVR with object detection (local cameras, MyQ bridge, remote RV camera over Tailscale)
- **Ingress:** Caddy for LAN access; Cloudflare Tunnel + Caddy + CrowdSec for public access
- **MinIO, Media Cloud, AI Tools**

## 🎯 Deployment Pattern

1. Helm charts for complex apps
2. `default-values.yaml` - Copy of chart defaults for reference
3. `values.yaml` - **Only customizations** from defaults
4. Setup scripts / Makefile for automation
5. External PostgreSQL (CloudNativePG) for persistence
6. Docker hosts run Compose from their `docker/<host>/` folder (media-cloud clones this repo via automation)

**Configuration Philosophy:**
- Keep `values.yaml` minimal (only changes from defaults)
- Document original defaults for reference
- Use setup scripts for repeatable deployments
- Keep live config in sync with Git (e.g. `talos-configs/sync-configs.sh`)
- Secrets live in 1Password, never in the repo

## 🔐 Security & Access

### Secrets Management
- **1Password:** Primary secret store
- **K8s Secrets:** Created manually from 1Password values
- **Pattern:** `kubectl create secret generic <name> --from-literal=key=value`
- **Docker:** `.env` files and `secrets.yaml` are gitignored; `*.example` files show the expected keys
- **Talos:** Machine configs are committed redacted; `merge-secrets.sh` restores them for recovery

### Access Control
- **Network:** Internal `.home.jasongodson.com` domain, restricted to the LAN
- **TLS:** Terminated by Caddy on the local ingress host with a wildcard cert (Cloudflare DNS challenge), which proxies to Traefik and Docker hosts
- **Public:** Only via Cloudflare Tunnel (no open router ports), protected by CrowdSec
- **Admin Users:** Manually created by admin
- **Registration:** Disabled for security

## 📂 Key File Paths (relative to repo root)

- **Kubernetes:** `k8s-configs/`
- **Talos:** `talos-configs/`
- **Docker:** `docker/`
- **Scripts:** `scripts/`

## 💡 Design Philosophy

- **Simple & Reliable:** Well-documented, production-ready practices
- **Kubernetes-native where it fits:** Helm charts, shell scripts, external secrets; Docker for hardware-bound or standalone services
- **Scale:** Single-user homelab with enterprise patterns
- **Focus:** Infrastructure automation, monitoring, CI/CD, home automation
