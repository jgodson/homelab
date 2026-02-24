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

### 1. Install CloudNativePG Operator

```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update

helm install cnpg \
  --namespace cnpg-system \
  --create-namespace \
  cnpg/cloudnative-pg
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

Backup is already configured in `cluster.yaml` (continuous WAL archiving + barmanObjectStore) and `scheduled-backup.yaml` (daily base backups at 3 AM). Backups are stored in MinIO and replicated offsite via rclone.

### What's Backed Up

- **Continuous WAL archiving**: Every WAL segment is compressed (gzip) and uploaded to MinIO as it's produced. Enables point-in-time recovery.
- **Daily base backups**: Full base backup at 3:00 AM daily, compressed with gzip, 30-day retention.
- **Offsite replication**: rclone syncs the `cnpg-backups` bucket every 6 hours.
- **Storage**: MinIO bucket `cnpg-backups` at `http://192.168.1.252:9000`

### Prerequisites

The backup config in `cluster.yaml` expects a MinIO bucket and K8s secret to already exist. If deploying from scratch (or after a full disaster recovery), create them first:

1. Create the `cnpg-backups` bucket and a dedicated MinIO user:
   ```bash
   # Inside the MinIO container
   mc alias set local http://localhost:9000 <root-user> <root-password>
   mc mb local/cnpg-backups
   mc admin user add local cnpg-backup-homelab <password>
   mc admin policy attach local readwrite --user cnpg-backup-homelab
   ```

2. Create the Kubernetes secret:
   ```bash
   kubectl create secret generic cnpg-minio-credentials \
     --from-literal=ACCESS_KEY_ID=cnpg-backup-homelab \
     --from-literal=ACCESS_SECRET_KEY=<password> \
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

# Check MinIO bucket contents (on minio host)
sudo docker exec -it minio mc ls local/cnpg-backups/postgresql-pg/ --recursive
```

### Disaster Recovery

#### Scenario 1: Restore from MinIO (MinIO is healthy)

If the CNPG cluster is lost but MinIO still has the backups, create a recovery cluster:

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

# 2. Ensure the MinIO credentials secret exists
kubectl get secret cnpg-minio-credentials -n postgresql

# 3. Apply the recovery cluster
kubectl apply -f recovery-cluster.yaml

# 4. Watch recovery progress
kubectl get cluster -n postgresql -w
kubectl logs -f -n postgresql -l cnpg.io/cluster=postgresql-pg

# 5. Once healthy, re-apply the scheduled backup
kubectl apply -f scheduled-backup.yaml
```

#### Scenario 2: Full disaster recovery (MinIO is also lost)

If both CNPG and MinIO are gone, restore from the offsite copy.

```bash
# 1. Get MinIO running again (redeploy VM/container, fresh install is fine)

# 2. Recreate the cnpg-backups bucket
sudo docker exec -it minio mc alias set local http://localhost:9000 <root-user> <root-password>
sudo docker exec -it minio mc mb local/cnpg-backups

# 3. Recreate the backup user
sudo docker exec -it minio mc admin user add local cnpg-backup-homelab <password>
sudo docker exec -it minio mc admin policy attach local readwrite --user cnpg-backup-homelab

# 4. Pull backups from offsite back to MinIO
#    Option A: Use rclone from the MinIO host
rclone sync gdrive:homelab-backups/cnpg-backups minio:cnpg-backups

#    Option B: Use the Docker rclone-sync service (reverse direction)
#    Edit the rclone command temporarily to sync FROM offsite TO minio

# 5. Verify backup files are present
sudo docker exec -it minio mc ls local/cnpg-backups/postgresql-pg/ --recursive

# 6. Recreate the K8s secret
kubectl create secret generic cnpg-minio-credentials \
  --from-literal=ACCESS_KEY_ID=cnpg-backup-homelab \
  --from-literal=ACCESS_SECRET_KEY=<password> \
  -n postgresql

# 7. Apply the recovery cluster (same YAML as Scenario 1 above)
kubectl apply -f recovery-cluster.yaml

# 8. Watch recovery, then re-apply scheduled backup
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
Continuous WAL archiving + daily base backups to MinIO with 30-day retention.

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
