---
title: Migrating from Bitnami PostgreSQL to CloudNativePG
description: How I migrated my homelab PostgreSQL databases from Bitnami to CloudNativePG after Broadcom paywalled their Bitnami images.
date: 2025-10-23
tags:
  - kubernetes
  - postgresql
  - database
  - homelab
  - infrastucture
layout: post.njk
---

As I mentioned in my post about [adding a Talos VIP to keep my cluster highly available](/blog/talos-vip-ha), I have been creating a automated shutdown workflow for my Proxmox VM's to safely shut them down. Part of that is cordoning and draining a Kubernetes node before shutting it down. Well, when I did that and my Postgres DB was moved to a new pod, it was suddenly having issues pulling the image!

## The Crisis: Broadcom Paywalls Bitnami

Broadcom (owner of Bitnami) [eliminated the free tier](https://github.com/bitnami/containers/issues/83267) for all Bitnami Docker images and removed them from the `bitnami` org on Docker Hub. For homelabs and small projects using Bitnami Helm charts, this was a critical infrastructure failure.

Originally I was under the impression that they were gone completely, but later learned they moved them to a [bitnamilegacy org](https://hub.docker.com/r/bitnamilegacy/postgresql/tags), so *I could have switched to that image*. Now that said, I'm still very happy with CloudNativePG and it was a simple migration.

## My Solution: CloudNativePG

[CloudNativePG](https://cloudnative-pg.io/) is a [CNCF Sandbox project](https://www.cncf.io/projects/cloudnativepg/) that provides Kubernetes-native PostgreSQL management with:

- ✅ High Availability (automatic failover)
- ✅ Streaming replication
- ✅ Point-in-time recovery
- ✅ Continuous backup
- ✅ Uses their own PostgreSQL images (no vendor paywall)

## Migration Journey

### Issue #1: Service Account Token Mount Failure

**Error**: 
```bash
open /var/run/secrets/kubernetes.io/serviceaccount/token: no such file or directory
```

**Root Cause**: When the cluster name matches the namespace name, CloudNativePG creates a service account with a conflicting name, preventing proper token mounting.

**Solution**: Rename the cluster to differ from the namespace:
```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgresql-pg  # Different from namespace!
  namespace: postgresql
```

**Reference**: [CloudNativePG GitHub Issue](https://github.com/cloudnative-pg/cloudnative-pg/issues/8107)

### Issue #2: User ID Mismatch

Originally I had tried to use the official Postgres image, but I ran into an issue with that.

**Error**:
```bash
initdb: could not look up effective user ID 26: user does not exist
```

**Root Cause**: CloudNativePG uses UID 26 for the postgres user, but the official Docker Hub `postgres:16-bookworm` image uses UID 999.

**Solution**: Use CloudNativePG's PostgreSQL images:
```yaml
spec:
  imageName: ghcr.io/cloudnative-pg/postgresql:16-bookworm  # Not postgres:16-bookworm!
```

These images are based on official PostgreSQL but configured for CloudNativePG's UID requirements.

## Working Configuration

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgresql-pg  # Must differ from namespace
  namespace: postgresql
spec:
  instances: 2  # Primary + 1 replica for HA
  
  # Use CloudNativePG's postgres image (UID 26)
  imageName: ghcr.io/cloudnative-pg/postgresql:16-bookworm
  
  # Storage configuration
  storage:
    storageClass: ceph-rbd
    size: 50Gi
  
  # Resource limits
  resources:
    requests:
      memory: "1Gi"
      cpu: "250m"
    limits:
      memory: "2Gi"
      cpu: "1"
  
  # Bootstrap - we'll import the backup later
  bootstrap:
    initdb:
      database: postgres
      owner: postgres
  
  # Enable superuser access
  enableSuperuserAccess: true
  
  # PostgreSQL configuration
  postgresql:
    parameters:
      max_connections: "200"
      shared_buffers: "256MB"
      effective_cache_size: "1GB"
```

## Migration Steps

### 1. Install CloudNativePG Operator

```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update

helm install cnpg \
  --namespace cnpg-system \
  --create-namespace \
  cnpg/cloudnative-pg
```

### 2. Backup Existing Data

I use Postgres only for Gitea at the moment and am guilty of not having a regular backup for it. Unfortunately with the container no longer being able to pull the image, I had a problem. I couldn't back up the current state since it wasn't running. That's when I had an idea - the old node probably still had the image cached!

I added some config to make sure it would schedule it on that node again:

```bash
  # Pin to kube-private-1 (the node with cached Bitnami image)
spec:
  nodeSelector:
    kubernetes.io/hostname: kube-private-1
```

Success, up and running! Now I was able to take a new backup:

```bash
# Create backup from the old pod
kubectl exec -n postgresql postgresql-0 -- \
  pg_dumpall -U postgres > ~/postgresql-backup-$(date +%Y%m%d-%H%M%S).sql
```

### 3. Create New Cluster

```bash
kubectl apply -f cluster.yaml

# Wait for healthy state
kubectl get cluster -n postgresql -w
```

### 4. Restore Backup

```bash
# Get the superuser password
PGPASSWORD=$(kubectl get secret -n postgresql postgresql-pg-superuser \
  -o jsonpath='{.data.password}' | base64 -d)

# Restore
cat ~/postgresql-backup-*.sql | \
  kubectl exec -i -n postgresql postgresql-pg-1 -- \
  env PGPASSWORD=$PGPASSWORD psql -U postgres
```

### 5. Verify Data

```bash
# List databases
kubectl exec -n postgresql postgresql-pg-1 -- psql -U postgres -c '\l'

# Check tables in your app database (gitea in my case)
kubectl exec -n postgresql postgresql-pg-1 -- \
  psql -U postgres -d gitea -c '\dt'
```

### 6. Update Application Connection Strings

CloudNativePG creates three services:

- **postgresql-pg-rw** - Read-write (primary) - *Generally this is what you want*
- **postgresql-pg-ro** - Read-only (replicas)
- **postgresql-pg-r** - Read (any instance)

Update your app to use: `postgresql-pg-rw.postgresql.svc.cluster.local:5432`

## Results

- **High Availability**: 2 instances with automatic failover
- **Data Safety**: Streaming replication between instances
- **No Vendor Lock-in**: Uses CloudNativePG's open-source images
- **Better Features**: Built-in backup, monitoring, and recovery capabilities

## Key Takeaways

1. **CloudNativePG is production-ready**: Easier HA features than Bitnami chart
2. **Migration is straightforward**: pg_dumpall → new cluster → restore
3. **Always keep backups**: Things always break at the worst times

## What's Next?

Stay tuned for the full story of the full Proxmox automation workflow as well as one more issue I ran into during the creation of it.

Also, I'm going to get those scheduled backups running 😅

#### Update (October 25, 2025)

The Proxmox automated restart post is up! Check out [Automating Proxmox Host Restarts with Gitea Actions](/blog/proxmox-restart-automation) for the full story.

---

## Resources

- [CloudNativePG Documentation](https://cloudnative-pg.io/documentation/current)
- [CloudNativePG GitHub](https://github.com/cloudnative-pg/cloudnative-pg)