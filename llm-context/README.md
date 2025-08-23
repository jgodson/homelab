# 🤖 LLM Context - Jason's Homelab

**Purpose:** Complete context for AI assistants to understand the homelab setup efficiently.

## 🏗️ Infrastructure Stack

**Core Platform:**
- **Kubernetes:** Primary orchestration (bare metal cluster)
- **Storage:** Ceph RBD for persistent volumes
- **Networking:** Traefik ingress, MetalLB load balancer
- **DNS:** Local domain `*.home.jasongodson.com`

**Key Technologies:**
- **Monitoring:** Prometheus, Grafana, Loki, Tempo, InfluxDB2
- **Database:** PostgreSQL cluster (external to apps)
- **Git/CI:** Gitea with Actions runners
- **Container Registry:** Integrated with Gitea
- **Secrets:** 1Password integration for sensitive data

## 📁 Repository Structure

```
homelab/
├── k8s-configs/          # Kubernetes deployments
│   ├── gitea/           # Git service + CI/CD
│   │   ├── default_values.yaml   # Original chart defaults
│   │   ├── values.yaml           # Only customizations
│   │   ├── namespace.yaml        # Namespace definition
│   │   └── setup-*.sh           # Deployment scripts
│   ├── monitoring/      # Observability stack
│   │   ├── grafana/     # Each service has own folder
│   │   ├── prometheus/  # Same pattern: default_values.yaml + values.yaml
│   │   └── loki/        # Plus setup scripts
│   ├── postgresql/      # Database cluster
│   └── traefik/         # Ingress controller
├── docker/              # Docker Compose services (local dev)
├── scripts/             # Global automation scripts
├── observability-config/# Monitoring agent configs
└── llm-context/         # This folder - AI context
```

## 📋 Helm Chart Standards

### Required Files per Service
- `default_values.yaml` - Copy of original chart defaults (reference)
- `values.yaml` - **ONLY** customizations from defaults
- `namespace.yaml` - Namespace definition + any policies
- `setup-*.sh` - Deployment automation scripts

### Philosophy
- **Minimal values.yaml:** Only override what you need to change
- **Keep defaults visible:** `default_values.yaml` for reference
- **Scriptable:** Setup scripts for consistent deployment

## 🔧 Current Active Services

**Production Services:**
- **Gitea:** https://gitea.home.jasongodson.com (Git + Actions)
- **Grafana:** Monitoring dashboards
- **PostgreSQL:** Shared database cluster
- **Traefik:** Reverse proxy + SSL termination

**Development/Testing:**
- **Docker services:** Local development stack
- **CI/CD:** Gitea Actions with 2 parallel runners

## 🎯 Deployment Pattern

1. Helm charts for complex apps
2. `default_values.yaml` - Copy of chart defaults for reference
3. `values.yaml` - **Only customizations** from defaults
4. Setup scripts for automation
5. External PostgreSQL for persistence

**Configuration Philosophy:**
- Keep `values.yaml` minimal (only changes from defaults)
- Document original defaults for reference
- Use setup scripts for repeatable deployments
- External secrets via 1Password integration

## 🔐 Security & Access

### Secrets Management
- **1Password:** Primary secret store
- **K8s Secrets:** Runtime secret injection
- **Pattern:** `kubectl create secret generic <name> --from-literal=key=value`

### Access Control
- **Network:** Internal `.home.jasongodson.com` domain
- **SSL:** Automatic via Traefik + Let's Encrypt
- **Admin Users:** Manually created by admin
- **Registration:** Disabled for security

## � Key File Paths

- **Configs:** `/Users/jasongodson/Documents/github/homelab/k8s-configs/`
- **Scripts:** `/Users/jasongodson/Documents/github/homelab/scripts/`
- **Docker:** `/Users/jasongodson/Documents/github/homelab/docker/`

## 💡 Design Philosophy

- **Simple & Reliable:** Well-documented, production-ready practices
- **Kubernetes-native:** Helm charts, shell scripts, external secrets
- **Scale:** Single-user homelab with enterprise patterns
- **Focus:** Infrastructure automation, monitoring, CI/CD
