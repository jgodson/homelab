# Gitea Setup

Gitea is a lightweight, fast, and simple Git service - perfect for homelab use. This setup uses external PostgreSQL with file-based sessions and memory caching for simplicity.

## 🚀 Quick Setup

### Prerequisites
1. **Create database secret** (stored in 1Password):
   ```bash
   kubectl create secret generic gitea-postgresql-secret -n gitea \
     --from-literal=password='<PASSWORD_FROM_1PASSWORD>'
    ```

2. **Run the setup script:**
   ```bash
   ./setup-gitea.sh
   ```

3. **Access Gitea:**
   - **URL:** https://gitea.home.jasongodson.com
   - **Username:** `admin`
   - **Password:** `changeme123!`

## 🏃‍♂️ Actions Runners Setup

To enable CI/CD workflows:

1. **Get runner registration token:**
   - Visit https://gitea.home.jasongodson.com/user/settings/actions/runners
   - Generate a new registration token

2. **Create runner token secret:**
   ```bash
   kubectl create secret generic gitea-runner-token -n gitea \
     --from-literal=token='<REGISTRATION_TOKEN>'
   ```

3. **Deploy runners:**
   ```bash
   ./setup-actions-runners.sh
   ```

### Actions Runner Configuration

The runners are deployed using the [gitea/helm-actions](https://gitea.com/gitea/helm-actions) chart, which provides:
- **Docker-in-Docker** support for building containers
- **2 parallel runners** for concurrent job execution
- **Custom labels:** `self-hosted`, `kubernetes`, `linux`, `x64`, `ansible`
- **Privileged containers** enabled for Docker builds

Configuration files:
- `actions-runner-values.yaml` - Helm chart values
- `namespace.yaml` - Includes PodSecurity policy for privileged containers

## 🏃 Actions Runners Information

### Available Runner Labels

- **`homelab-latest`**: Custom container with homelab-specific tools
  - Use for: Standard CI tasks, testing, non-Docker builds

- **`host-docker`**: Host mode with Docker access  
  - Use for: Docker builds, container operations, registry pushes

## 🎯 Getting Started

### First Login
1. Visit https://gitea.home.jasongodson.com
2. Login with `admin` / `changeme123!`
3. **Important:** Change the admin password immediately
4. Configure your profile and email settings

### Create Your First Repository
1. Click **"+"** → **"New Repository"**
2. Set repository name and visibility
3. Initialize with README if desired
4. Clone and start coding!

### Setting Up CI/CD with Gitea Actions

Gitea Actions is GitHub Actions compatible! Create `.gitea/workflows/ci.yml`:

```yaml
name: CI Pipeline
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: |
          echo "Running tests..."
          # Add your test commands here
          
  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - name: Deploy
        run: |
          echo "Deploying to production..."
          # Add deployment commands here
```

### Building Docker Containers
To build Docker containers in your CI/CD pipelines, use the `host-docker` runner label for full Docker access:

```yaml
jobs:
  build:
    runs-on: host-docker
    steps:
      - uses: actions/checkout@v4
      - name: Build Docker image
        run: |
          docker build -t myapp:${{ github.sha }} .
      - name: Push to registry
        env:
          DOCKER_USER: ${{ secrets.DOCKER_USER }}
          DOCKER_PASS: ${{ secrets.DOCKER_PASS }}
        run: |
          echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin registry.example.com
          docker push registry.example.com/myapp:${{ github.sha }}
```

## 🔄 Maintenance

### Backup
```bash
# Gitea data backup
kubectl exec -n gitea deployment/gitea -- gitea dump
```

### Updates
```bash
# Update Gitea server
helm repo update
helm upgrade gitea gitea-charts/gitea -n gitea -f values.yaml

# Update Actions runners
./deploy-runners.sh
```

### Monitor Resources
```bash
kubectl top pods -n gitea
kubectl get pvc -n gitea
```
