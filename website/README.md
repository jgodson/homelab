# Local development

`npm install`

`npm run dev`

### Visit local server at http://localhost:8080

# Build with versioned assets

`npm run build`

# Deployment

The website is containerized and deployed to a Kubernetes cluster.

### 1. Build and Push Image

Build the Docker image using the provided `Dockerfile`. Ensure you tag it appropriately for your registry.

```bash
docker build -t your-registry/personal-website:latest .
docker push your-registry/personal-website:latest
```

### 2. Deploy to Kubernetes

The Kubernetes manifests are located in the `k8s/` directory.

1. Update the placeholders in `k8s/deployment.yaml` (or use a deployment script/tooling):
   - `{{APP_NAME}}`
   - `{{NAMESPACE}}`
   - `{{IMAGE}}`
   - `{{REGISTRY_SECRET_NAME}}`

2. Apply the configuration:

```bash
kubectl apply -f k8s/deployment.yaml
```

### 3. Public Access

The website is still proxied through a public Caddy ingress. Ensure the Caddyfile in `homelab/docker/ingress-public/caddy/Caddyfile` is configured to reverse proxy to the cluster's ingress controller.