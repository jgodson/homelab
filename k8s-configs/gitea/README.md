# Gitea Setup

Gitea is a lightweight, fast, and simple Git service - perfect for homelab use. This setup uses external PostgreSQL with file-based sessions and memory caching for simplicity.

## 🚀 Quick Setup

### Prerequisites
1. **Database:** PostgreSQL cluster must be running (see `/k8s-configs/cnpg-system/`)

2. **Create database secret** (stored in 1Password):
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

3. **Create Docker registry credentials secret** (for pulling private images):
   ```bash
   kubectl create secret docker-registry gitea-registry-secret -n gitea \
     --docker-server=gitea.home.jasongodson.com \
     --docker-username='<USERNAME>' \
     --docker-password='<PASSWORD>'
   ```

4. **Deploy runners:**
   ```bash
   ./deploy-runners.sh
   ```

### Actions Runner Configuration

The runners are deployed using the [gitea/helm-actions](https://gitea.com/gitea/helm-actions) chart, which provides:
- **Docker-in-Docker** support for building containers
- **2 parallel runners** for concurrent job execution
- **Custom labels:** `homelab-latest`, `host-docker`
- **Privileged containers** enabled for Docker builds
- **Automated Docker authentication** via mounted registry secret

Configuration files:
- `actions-runner-values.yaml` - Helm chart values
- `namespace.yaml` - Includes PodSecurity policy for privileged containers
- `dind-daemon-config.yaml` - DinD Docker daemon config (MTU fix, see below)

#### Docker-in-Docker MTU Fix

The DinD sidecar runs its own Docker bridge network at a default MTU of 1500. However, the Kubernetes pod network (Flannel) uses MTU 1450. This mismatch causes large TLS packets from Docker build containers to be silently dropped, making all HTTPS downloads hang during `docker build`. The `dind-daemon-config.yaml` ConfigMap sets the DinD bridge MTU to 1450 to match the overlay network. This is applied automatically by `deploy-runners.sh`.

#### Docker Registry Authentication

The runners need to authenticate with the Gitea Docker registry to pull private images. This is handled by mounting the `gitea-registry-secret` (type `kubernetes.io/dockerconfigjson`) directly into both the act-runner and DinD containers at `/root/.docker`. This survives pod restarts and rollouts with no extra jobs needed.

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

### Setting Up the Docker Registry

Gitea includes a built-in Docker registry for hosting container images. This setup uses the `homelab` organization for shared images.

1. **Create the homelab organization** (if it does not already exist):
   - Click **"+"** → **"New Organization"**
   - Organization name: `homelab`
   - Visibility: Private (or as desired)

2. **Create a repository for your container image**:
   - Navigate to the `homelab` organization
   - Click **"New Repository"**
   - Repository name: `actions-runner` (or your image name)
   - This repository serves as the namespace for your container package

3. **Create a Personal Access Token** (for Docker authentication):
   - Go to **Settings** → **Applications** → **Manage Access Tokens**
   - Click **Generate New Token**
   - Give it a name (e.g., "Docker Registry")
   - Select scopes: `write:package`, `read:package`
   - Copy the token immediately (it won't be shown again)

4. **Login to the registry from your local machine**:
   ```bash
   echo "<YOUR_TOKEN>" | docker login gitea.home.jasongodson.com -u <USERNAME> --password-stdin
   ```

5. **Build and push your custom runner image**:
   ```bash
   # Build your custom image (example)
   docker build -t gitea.home.jasongodson.com/homelab/actions-runner:latest .
   
   # Push to Gitea registry
   docker push gitea.home.jasongodson.com/homelab/actions-runner:latest
   
   # Push with version tag
   docker tag gitea.home.jasongodson.com/homelab/actions-runner:latest \
     gitea.home.jasongodson.com/homelab/actions-runner:20251017
   docker push gitea.home.jasongodson.com/homelab/actions-runner:20251017
   ```

6. **View your packages**:
   - Visit `https://gitea.home.jasongodson.com/homelab/-/packages`
   - You'll see all packages under the homelab organization
   - Example: `https://gitea.home.jasongodson.com/homelab/-/packages/container/actions-runner/latest`

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
