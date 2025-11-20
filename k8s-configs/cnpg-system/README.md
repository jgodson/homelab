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

### 4. Restore PostgreSQL backup (if you have one)

```bash
# Get the superuser password
PGPASSWORD=$(kubectl get secret -n postgresql postgresql-pg-superuser -o jsonpath='{.data.password}' | base64 -d)

# Restore from backup
cat ~/postgresql-backup-YYYYMMDD-HHMMSS.sql | \
  kubectl exec -i -n postgresql postgresql-pg-1 -- \
  env PGPASSWORD=$PGPASSWORD psql -U postgres
```

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

## Backup Configuration (Optional)

Add to `cluster.yaml`:

```yaml
spec:
  backup:
    barmanObjectStore:
      destinationPath: s3://my-bucket/postgresql-backups
      s3Credentials:
        accessKeyId:
          name: backup-credentials
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: backup-credentials
          key: SECRET_ACCESS_KEY
      wal:
        compression: gzip
    retentionPolicy: "30d"
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

### Automated Backups (Recommended)

CloudNativePG supports automated backups to S3-compatible storage. Add to `cluster.yaml`:

```yaml
spec:
  backup:
    barmanObjectStore:
      destinationPath: s3://my-bucket/postgresql-backups
      s3Credentials:
        accessKeyId:
          name: backup-credentials
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: backup-credentials
          key: SECRET_ACCESS_KEY
      wal:
        compression: gzip
    retentionPolicy: "30d"
    
  # Schedule automatic backups
  scheduledBackup:
    - name: daily-backup
      schedule: "0 0 2 * * *"  # 2 AM daily
      backupOwnerReference: self
```

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
