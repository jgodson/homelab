# Shared PostgreSQL for Homelab

This PostgreSQL deployment serves as a shared database server for multiple applications in your homelab, providing centralized database management, easier backups, and better resource utilization.

## Features

- **Shared Database Server**: Multiple databases for different applications
- **Automated Backups**: Daily backups with retention
- **Monitoring Integration**: Prometheus metrics enabled  
- **Resource Optimized**: Single PostgreSQL instance for efficiency
- **Ceph Storage**: Persistent storage with your existing storage class

## Supported Applications

This PostgreSQL instance is configured to support:
- **GitLab** (gitlab_production, gitlab_production_ci databases)
- **Future Applications** (easily add more databases)

## Installation Steps

### 1. Create Database Credentials Secret

```bash
# Generate secure passwords
POSTGRES_PASSWORD=$(openssl rand -base64 32)
GITLAB_PASSWORD=$(openssl rand -base64 32)

# Create the main PostgreSQL secret
kubectl create secret generic postgresql-credentials \
  --from-literal=postgres-password="$POSTGRES_PASSWORD" \
  -n postgresql

# Store passwords for later use
echo "PostgreSQL Admin Password: $POSTGRES_PASSWORD"
echo "GitLab Database Password: $GITLAB_PASSWORD"
```

### 2. Update Database Initialization Script

Edit the `values.yaml` file and replace the placeholder passwords in the init script:

```bash
# Replace GITLAB_PASSWORD_PLACEHOLDER with the actual password
sed -i "s/GITLAB_PASSWORD_PLACEHOLDER/$GITLAB_PASSWORD/g" values.yaml
```

### 3. Add Bitnami Helm Repository

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

### 4. Create Namespace and Install PostgreSQL

```bash
# Create namespace
kubectl apply -f namespace.yaml

# Install PostgreSQL
helm install postgresql bitnami/postgresql \
  -n postgresql \
  --values values.yaml
```

### 5. Create Application-Specific Secrets

For GitLab:
```bash
kubectl create secret generic gitlab-postgresql-secret \
  --from-literal=password="$GITLAB_PASSWORD" \
  -n gitlab
```

For other applications, create similar secrets in their respective namespaces.

## Adding New Applications

### 1. Update the Database Schema

Add new database creation commands to the `values.yaml` file in the initdb scripts section:

```sql
CREATE DATABASE myapp_production;
```

### 2. Upgrade the PostgreSQL Deployment

```bash
helm upgrade postgresql bitnami/postgresql \
  -n postgresql \
  --values values.yaml
```

### 3. Create Application User and Secret

```bash
# Generate a secure password for the new application
MYAPP_PASSWORD=$(openssl rand -base64 32)

# Get PostgreSQL admin password
POSTGRES_PASSWORD=$(kubectl get secret --namespace postgresql postgresql-credentials -o jsonpath="{.data.postgres-password}" | base64 -d)

# Create the database user manually
kubectl exec -it postgresql-0 -n postgresql -- bash -c "
PGPASSWORD='$POSTGRES_PASSWORD' psql -U postgres -c \"
CREATE USER myapp WITH PASSWORD '$MYAPP_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE myapp_production TO myapp;
\""

# Create the application secret
kubectl create secret generic myapp-postgresql-secret \
  --from-literal=password="$MYAPP_PASSWORD" \
  -n myapp-namespace

# Store the password securely for your records
```

### 4. Verify the Setup

```bash
kubectl exec -it postgresql-0 -n postgresql -- bash -c "PGPASSWORD='$MYAPP_PASSWORD' psql -U myapp -d myapp_production -c 'SELECT current_database(), current_user;'"
```

## Database Connection Details

Applications should connect using these details:

- **Host**: `postgresql.postgresql.svc.cluster.local`
- **Port**: `5432`
- **Username**: `<app-specific-user>` (e.g., `gitlab`)
- **Password**: From Kubernetes secret
- **Database**: `<app-specific-database>` (e.g., `gitlab_production`)

## Backups

### Internal Backups (Automated)

**Purpose**: Protect against operational mistakes within applications
- Bad application updates
- Accidental data deletion
- Failed schema migrations
- User errors

**What it does**:
- Daily backups at 1 AM to Ceph storage
- Keeps ~7 days of rolling backups
- Quick recovery for single database issues

### Manual/External Backups (Recommended for DR)

**Purpose**: Protect against infrastructure failures
- Storage system failure (Ceph cluster issues)
- Kubernetes cluster failure  
- Site-wide issues (power, network, hardware)

#### Per-Database Backup Commands

```bash
# Backup a specific application's database
kubectl exec postgresql-0 -n postgresql -- pg_dump -U postgres gitlab_production > gitlab_backup_$(date +%Y%m%d).sql

# Backup all databases for a comprehensive backup
kubectl exec postgresql-0 -n postgresql -- pg_dumpall -U postgres > full_backup_$(date +%Y%m%d).sql

# Restore a specific database (if you mess up an app)
kubectl exec -i postgresql-0 -n postgresql -- psql -U postgres -d gitlab_production < gitlab_backup_20250618.sql
```

#### Automated External Backups with GitLab CI/CD

Once GitLab is running, create a scheduled pipeline for external backups:

```yaml
# .gitlab-ci.yml for database backup project
stages:
  - backup-internal
  - backup-external

# Quick operational backup (single DB)
backup-gitlab:
  stage: backup-internal
  image: postgres:16
  script:
    - pg_dump -h postgresql.postgresql.svc.cluster.local -U gitlab gitlab_production > gitlab_backup.sql
    - # Keep locally for quick recovery
  artifacts:
    expire_in: 7 days
    paths:
      - gitlab_backup.sql

# Full external backup for disaster recovery
backup-external:
  stage: backup-external
  image: postgres:16
  script:
    - pg_dumpall -h postgresql.postgresql.svc.cluster.local -U postgres > full_backup.sql
    - # Upload to external storage (S3, rsync to NAS, etc.)
    - aws s3 cp full_backup.sql s3://my-homelab-backups/postgresql/
  schedule: "0 3 * * 0"  # Weekly on Sunday at 3 AM
  only:
    - schedules
```

### Access Internal Backups

```bash
# List available backups
kubectl exec postgresql-0 -n postgresql -- ls -la /opt/bitnami/postgresql/backups/

# Download a specific backup for local recovery
kubectl cp postgresql/postgresql-0:/opt/bitnami/postgresql/backups/backup-20250618.sql ./local_backup.sql

# Restore from internal backup
kubectl exec -i postgresql-0 -n postgresql -- psql -U postgres < local_backup.sql
```

## Monitoring

PostgreSQL metrics are automatically exposed for Prometheus scraping:
- **Port**: 9187
- **Endpoint**: `/metrics`
- **Namespace**: postgresql

## Troubleshooting

### Connection Issues

```bash
# Check PostgreSQL pod status
kubectl get pods -n postgresql

# View PostgreSQL logs
kubectl logs -f postgresql-0 -n postgresql

# Test connection from another pod
kubectl run -it --rm debug --image=postgres:16 --restart=Never -- psql -h postgresql.postgresql.svc.cluster.local -U postgres
```

### Database User Management

#### Check Existing Users and Databases

```bash
# Get PostgreSQL admin password
POSTGRES_PASSWORD=$(kubectl get secret --namespace postgresql postgresql-credentials -o jsonpath="{.data.postgres-password}" | base64 -d)

# List all databases
kubectl exec -it postgresql-0 -n postgresql -- bash -c "PGPASSWORD='$POSTGRES_PASSWORD' psql -U postgres -c '\l'"

# List all users
kubectl exec -it postgresql-0 -n postgresql -- bash -c "PGPASSWORD='$POSTGRES_PASSWORD' psql -U postgres -c '\du'"

# Check user permissions on a specific database
kubectl exec -it postgresql-0 -n postgresql -- bash -c "PGPASSWORD='$POSTGRES_PASSWORD' psql -U postgres -d gitlab_production -c '\dp'"
```

#### Manual User Creation (if init script fails)

If the automatic user creation in the init script doesn't work, create users manually:

```bash
# Get the admin password
POSTGRES_PASSWORD=$(kubectl get secret --namespace postgresql postgresql-credentials -o jsonpath="{.data.postgres-password}" | base64 -d)

# Create GitLab user manually
kubectl exec -it postgresql-0 -n postgresql -- bash -c "
PGPASSWORD='$POSTGRES_PASSWORD' psql -U postgres -c \"
CREATE USER gitlab WITH PASSWORD 'YOUR_GITLAB_PASSWORD_HERE';
GRANT ALL PRIVILEGES ON DATABASE gitlab_production TO gitlab;
GRANT ALL PRIVILEGES ON DATABASE gitlab_production_ci TO gitlab;
\""

# For other applications, follow the same pattern:
kubectl exec -it postgresql-0 -n postgresql -- bash -c "
PGPASSWORD='$POSTGRES_PASSWORD' psql -U postgres -c \"
CREATE USER myapp WITH PASSWORD 'YOUR_APP_PASSWORD_HERE';
GRANT ALL PRIVILEGES ON DATABASE myapp_production TO myapp;
\""
```

#### Test User Connections

```bash
# Test GitLab user connection
GITLAB_PASSWORD=$(kubectl get secret --namespace gitlab gitlab-postgresql-secret -o jsonpath="{.data.password}" | base64 -d)
kubectl exec -it postgresql-0 -n postgresql -- bash -c "PGPASSWORD='$GITLAB_PASSWORD' psql -U gitlab -d gitlab_production -c 'SELECT current_database(), current_user;'"

# Test if user can create tables (verify permissions)
kubectl exec -it postgresql-0 -n postgresql -- bash -c "PGPASSWORD='$GITLAB_PASSWORD' psql -U gitlab -d gitlab_production -c 'CREATE TABLE test_table (id SERIAL PRIMARY KEY); DROP TABLE test_table;'"
```

### Storage Issues

```bash
# Check persistent volume claims
kubectl get pvc -n postgresql

# Check storage usage
kubectl exec postgresql-0 -n postgresql -- df -h
```

### Performance Issues

```bash
# Check current PostgreSQL configuration
kubectl exec -it postgresql-0 -n postgresql -- bash -c "PGPASSWORD='$POSTGRES_PASSWORD' psql -U postgres -c 'SHOW ALL;'" | grep -E 'max_connections|shared_buffers|effective_cache_size|work_mem|maintenance_work_mem'

# Check active connections
kubectl exec -it postgresql-0 -n postgresql -- bash -c "PGPASSWORD='$POSTGRES_PASSWORD' psql -U postgres -c 'SELECT count(*) FROM pg_stat_activity;'"

# Check database sizes
kubectl exec -it postgresql-0 -n postgresql -- bash -c "PGPASSWORD='$POSTGRES_PASSWORD' psql -U postgres -c 'SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database;'"
```