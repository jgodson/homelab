# CloudNativePG PostgreSQL

## Why CloudNativePG?

- ✅ Uses CloudNativePG's PostgreSQL images (based on official postgres but compatible with operator)
- ✅ CNCF Sandbox project (production-ready)
- ✅ Better features than Bitnami chart (HA, backups, monitoring)
- ✅ No vendor lock-in

## Important Notes

### Image Compatibility
- **Must use CloudNativePG images**: `ghcr.io/cloudnative-pg/postgresql:16-bookworm`
- **Cannot use official Docker Hub images**: `postgres:16-bookworm` (causes UID 26 errors)
- CloudNativePG uses UID 26 for postgres user, official images use UID 999

### Cluster Naming
- **Cluster name must be different from namespace** to avoid service account conflicts
- Example: namespace=`postgresql`, cluster=`postgresql-pg`
- See: https://github.com/cloudnative-pg/cloudnative-pg/issues/8107

## Installation

Current deployed operator:

- Helm chart: `cloudnative-pg-0.27.1`
- App/operator version: `1.28.1`

### 1. Install CloudNativePG Operator

```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update

helm install cnpg \
  --namespace cnpg-system \
  --create-namespace \
  --version 0.27.1 \
  cnpg/cloudnative-pg
```

For an existing install, upgrade to the tracked version with:

```bash
helm upgrade cnpg cnpg/cloudnative-pg \
  --namespace cnpg-system \
  --version 0.27.1
```

### 2. Create PostgreSQL Cluster

```bash
kubectl apply -f cluster.yaml
```

### 3. Wait for cluster to be ready

```bash
kubectl get cluster -n postgresql
kubectl get pods -n postgresql
```

### 4. Restore from backup (if needed)

If restoring from a previous backup, see [Disaster Recovery](#disaster-recovery) below.

### 5. Create application secrets

```bash
# Create secret for Gitea database user
kubectl create secret generic gitea-postgresql-secret \
  --from-literal=password='YOUR_GITEA_PASSWORD' \
  -n postgresql
```

### 6. Update application to use PostgreSQL

Update values to point to new service:
- Host: `postgresql-rw.postgresql.svc.cluster.local:5432`
- (CloudNativePG creates `-rw` read-write service automatically)

## Services Created

CloudNativePG automatically creates these services:

- `postgresql-rw` - Read-Write service (primary)
- `postgresql-ro` - Read-Only service (replicas, if any)
- `postgresql-r` - Read service (includes primary + replicas)

## Monitoring

CloudNativePG includes built-in Prometheus metrics. If you have Prometheus Operator:

```bash
kubectl get podmonitor -n postgresql
```

## Backup Configuration

Backup is already configured in `cluster.yaml` (continuous WAL archiving + barmanObjectStore) and `scheduled-backup.yaml` (daily base backups at 3 AM). Backups are stored in Garage (S3-compatible, on the `minio` VM) and replicated offsite via rclone.

### What's Backed Up

- **Continuous WAL archiving**: Every WAL segment is compressed (gzip) and uploaded to Garage as it's produced. Enables point-in-time recovery.
- **Daily base backups**: Full base backup at 3:00 AM daily, compressed with gzip, 7-day retention.
- **Offsite replication**: rclone syncs the `cnpg-backups` bucket every 6 hours.
- **Storage**: Garage bucket `cnpg-backups` at `http://192.168.1.252:9000`
- **Credentials**: Garage key `cnpg-backup-homelab` in the `cnpg-minio-credentials` secret (the secret keeps its pre-Garage name)

### Prerequisites

The backup config in `cluster.yaml` expects a Garage bucket, key and K8s secret to already exist. If deploying from scratch (or after a full disaster recovery), create them first:

1. Create the Garage key on the `minio` VM (the secret is printed once):
   ```bash
   sudo docker exec garage /garage key create cnpg-backup-homelab
   ```
   The `cnpg-backups` bucket and the key's read/write grant are managed in `homelab-automation` (`tofu/garage-buckets.tf`); add the key ID there and apply.

2. Create the Kubernetes secret:
   ```bash
   kubectl create secret generic cnpg-minio-credentials \
     --from-literal=ACCESS_KEY_ID=<GK key ID> \
     --from-literal=ACCESS_SECRET_KEY=<secret> \
     -n postgresql
   ```

3. Apply the cluster and scheduled backup as normal:
   ```bash
   kubectl apply -f cluster.yaml
   kubectl apply -f scheduled-backup.yaml
   ```

### Verifying Backups

```bash
# Check scheduled backup status
kubectl get scheduledbackups -n postgresql

# Check backup objects
kubectl get backups -n postgresql

# Check WAL archiving in cluster status
kubectl describe cluster postgresql-pg -n postgresql | grep -A5 "Last Successful Archival"

# List base backups stored in Garage (from a CNPG instance pod)
kubectl exec -n postgresql postgresql-pg-1 -c postgres -- env \
  AWS_ACCESS_KEY_ID=<GK key ID> AWS_SECRET_ACCESS_KEY=<secret> AWS_DEFAULT_REGION=us-east-1 \
  barman-cloud-backup-list --endpoint-url http://192.168.1.252:9000 s3://cnpg-backups/ postgresql-pg
```

### Disaster Recovery

#### Scenario 1: Restore from Garage (Garage is healthy)

If the CNPG cluster is lost but Garage still has the backups, create a recovery cluster:

```yaml
# recovery-cluster.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgresql-pg
  namespace: postgresql
spec:
  instances: 3
  imageName: ghcr.io/cloudnative-pg/postgresql:16-bookworm
  storage:
    storageClass: ceph-rbd
    size: 50Gi
  bootstrap:
    recovery:
      source: postgresql-pg-backup
      # Uncomment to recover to a specific point in time:
      # recoveryTarget:
      #   targetTime: "2026-02-22T17:00:00Z"
  externalClusters:
    - name: postgresql-pg-backup
      barmanObjectStore:
        destinationPath: "s3://cnpg-backups/"
        endpointURL: "http://192.168.1.252:9000"
        s3Credentials:
          accessKeyId:
            name: cnpg-minio-credentials
            key: ACCESS_KEY_ID
          secretAccessKey:
            name: cnpg-minio-credentials
            key: ACCESS_SECRET_KEY
```

```bash
# 1. Delete the broken cluster (if it still exists)
kubectl delete cluster postgresql-pg -n postgresql

# 2. Ensure the Garage credentials secret exists
kubectl get secret cnpg-minio-credentials -n postgresql

# 3. Apply the recovery cluster
kubectl apply -f recovery-cluster.yaml

# 4. Watch recovery progress
kubectl get cluster -n postgresql -w
kubectl logs -f -n postgresql -l cnpg.io/cluster=postgresql-pg

# 5. Once healthy, re-apply the scheduled backup
kubectl apply -f scheduled-backup.yaml
```

#### Scenario 2: Full disaster recovery (Garage is also lost)

If both CNPG and Garage are gone, restore from the offsite copy.

```bash
# 1. Get Garage running again (see docker/garage/README.md; a fresh install is fine)

# 2. Recreate the buckets and grants from homelab-automation (tofu apply),
#    after creating a new cnpg-backup-homelab key and adding its ID to garage-buckets.tf
sudo docker exec garage /garage key create cnpg-backup-homelab

# 3. Pull backups from offsite back to Garage, from the minio VM
#    (the rclone-sync config has "gdrive" and "garage" remotes; the garage
#    remote's key is read-only, so use a key with write access to cnpg-backups)
rclone sync gdrive:homelab-backups/cnpg-backups garage:cnpg-backups

# 4. Recreate the K8s secret
kubectl create secret generic cnpg-minio-credentials \
  --from-literal=ACCESS_KEY_ID=<GK key ID> \
  --from-literal=ACCESS_SECRET_KEY=<secret> \
  -n postgresql

# 5. Apply the recovery cluster (same YAML as Scenario 1 above)
kubectl apply -f recovery-cluster.yaml

# 6. Watch recovery, then re-apply scheduled backup
kubectl get cluster -n postgresql -w
kubectl apply -f scheduled-backup.yaml
```

#### Point-in-time recovery notes

- CNPG can recover to any point in time covered by WAL archiving
- The `targetTime` must be in RFC 3339 format: `"2026-02-22T17:00:00Z"`
- Without `recoveryTarget`, CNPG recovers to the latest available point
- WAL segments are archived continuously, so RPO is typically seconds to minutes
- Recovery time depends on base backup size + WAL replay (expect minutes for small DBs)

#### Verifying a restore

```bash
# Check cluster is healthy
kubectl get cluster -n postgresql

# Check all instances are running
kubectl get pods -n postgresql -l cnpg.io/cluster=postgresql-pg

# Verify databases exist
PGPASSWORD=$(kubectl get secret -n postgresql postgresql-pg-superuser -o jsonpath='{.data.password}' | base64 -d)
kubectl exec -it postgresql-pg-1 -n postgresql -- \
  env PGPASSWORD=$PGPASSWORD psql -U postgres -c '\l'

# Verify WAL archiving is active on the new cluster
kubectl describe cluster postgresql-pg -n postgresql | grep -A5 "Last Successful Archival"
```

## Resources

- Docs: https://cloudnative-pg.io/
- GitHub: https://github.com/cloudnative-pg/cloudnative-pg

## Database Management

### Connection Details

Applications should connect using:
- **Host**: `postgresql-pg-rw.postgresql.svc.cluster.local` (read-write)
- **Port**: `5432`
- **Username**: Application-specific user (e.g., `gitea`)
- **Password**: From Kubernetes secret
- **Database**: Application-specific database (e.g., `gitea`)

### Creating New Databases and Users

```bash
# Get the primary pod name
POD_NAME=$(kubectl get pods -n postgresql -l "cnpg.io/cluster=postgresql-pg,role=primary" -o jsonpath='{.items[0].metadata.name}')
PASSWORD=$(openssl rand -hex 64)
# Prefer underscores; hyphens require quoting in PostgreSQL identifiers
APP=myapp
NAMESPACE=default
SECRET_NAME="${APP}-db"

# Create a new database and user
kubectl exec -n postgresql "$POD_NAME" -- psql -U postgres -c "CREATE USER ${APP} WITH PASSWORD '${PASSWORD}';"
kubectl exec -n postgresql "$POD_NAME" -- psql -U postgres -c "CREATE DATABASE ${APP} OWNER ${APP};"

# Create Kubernetes secret for the application
kubectl create secret generic "${SECRET_NAME}" \
  --from-literal=DATABASE_URL="postgresql://${APP}:${PASSWORD}@postgresql-pg-rw.postgresql.svc.cluster.local:5432/${APP}" \
  --from-literal=username="${APP}" \
  --from-literal=password="${PASSWORD}" \
  --from-literal=dbname="${APP}" \
  -n "${NAMESPACE}" # App's namespace
```

### Listing Databases and Users

```bash
# Get superuser password
PGPASSWORD=$(kubectl get secret -n postgresql postgresql-pg-superuser -o jsonpath='{.data.password}' | base64 -d)

# List all databases
kubectl exec -it postgresql-pg-1 -n postgresql -- \
  env PGPASSWORD=$PGPASSWORD psql -U postgres -c '\l'

# List all users
kubectl exec -it postgresql-pg-1 -n postgresql -- \
  env PGPASSWORD=$PGPASSWORD psql -U postgres -c '\du'

# Check database sizes
kubectl exec -it postgresql-pg-1 -n postgresql -- \
  env PGPASSWORD=$PGPASSWORD psql -U postgres -c \
  "SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database;"
```

## Backups

### Manual Backup

```bash
# Backup specific database
kubectl exec postgresql-pg-1 -n postgresql -- \
  pg_dump -U postgres gitea > gitea_backup_$(date +%Y%m%d).sql

# Backup all databases
kubectl exec postgresql-pg-1 -n postgresql -- \
  pg_dumpall -U postgres > full_backup_$(date +%Y%m%d).sql
```

### Manual Restore

```bash
# Get superuser password
PGPASSWORD=$(kubectl get secret -n postgresql postgresql-pg-superuser -o jsonpath='{.data.password}' | base64 -d)

# Restore specific database
kubectl exec -i postgresql-pg-1 -n postgresql -- \
  env PGPASSWORD=$PGPASSWORD psql -U postgres -d gitea < gitea_backup.sql

# Restore all databases
kubectl exec -i postgresql-pg-1 -n postgresql -- \
  env PGPASSWORD=$PGPASSWORD psql -U postgres < full_backup.sql
```

### Automated Backups

Automated backups are configured - see [Backup Configuration](#backup-configuration) above for details.
Continuous WAL archiving + daily base backups to Garage with 7-day retention.

## Troubleshooting

### Check Cluster Status

```bash
# Check cluster health
kubectl get cluster -n postgresql

# Check pods
kubectl get pods -n postgresql

# View cluster details
kubectl describe cluster -n postgresql postgresql-pg

# Check operator logs
kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg
```

### Connection Issues

```bash
# View PostgreSQL logs
kubectl logs -f postgresql-pg-1 -n postgresql

# Test connection from debug pod
kubectl run -it --rm debug --image=postgres:16 --restart=Never -n postgresql -- \
  psql -h postgresql-pg-rw.postgresql.svc.cluster.local -U postgres

# Check services
kubectl get svc -n postgresql -l cnpg.io/cluster=postgresql-pg
```

### Performance Monitoring

```bash
# Get superuser password
PGPASSWORD=$(kubectl get secret -n postgresql postgresql-pg-superuser -o jsonpath='{.data.password}' | base64 -d)

# Check active connections
kubectl exec -it postgresql-pg-1 -n postgresql -- \
  env PGPASSWORD=$PGPASSWORD psql -U postgres -c \
  "SELECT count(*) as connections, usename, state FROM pg_stat_activity GROUP BY usename, state;"

# Check current configuration
kubectl exec -it postgresql-pg-1 -n postgresql -- \
  env PGPASSWORD=$PGPASSWORD psql -U postgres -c "SHOW ALL;" | \
  grep -E 'max_connections|shared_buffers|effective_cache_size'

# Check table sizes
kubectl exec -it postgresql-pg-1 -n postgresql -- \
  env PGPASSWORD=$PGPASSWORD psql -U postgres -d gitea -c \
  "SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) 
   FROM pg_tables ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC LIMIT 10;"
```

### Storage Issues

```bash
# Check PVC status
kubectl get pvc -n postgresql

# Check disk usage in pod
kubectl exec postgresql-pg-1 -n postgresql -- df -h /var/lib/postgresql/data
```

### High Availability Testing

```bash
# Check replication status
PGPASSWORD=$(kubectl get secret -n postgresql postgresql-pg-superuser -o jsonpath='{.data.password}' | base64 -d)

kubectl exec -it postgresql-pg-1 -n postgresql -- \
  env PGPASSWORD=$PGPASSWORD psql -U postgres -c \
  "SELECT client_addr, state, sync_state FROM pg_stat_replication;"

# Test failover (deletes primary pod, replica becomes primary)
kubectl delete pod postgresql-pg-1 -n postgresql

# Watch cluster recover
kubectl get cluster -n postgresql -w
```
