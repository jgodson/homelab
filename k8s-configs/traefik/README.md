### Traefik Setup Steps

1. **Add the Traefik Helm repository**
   ```bash
   helm repo add traefik https://traefik.github.io/charts
   helm repo update
   ```

2. **Install Traefik using Helm**
   ```bash
   helm install traefik traefik/traefik \
   -n traefik \
   --values values.yaml \
   --create-namespace
   ```

3. **Verify the deployment**
   ```bash
   kubectl get pods -n traefik
   kubectl get svc -n traefik
   ```

### Accessing the Dashboard

1. **Port-forward to the Traefik dashboard**
   ```bash
   kubectl port-forward -n traefik $(kubectl get pods -n traefik -l app.kubernetes.io/name=traefik -o name) 8080:8080
   ```

2. **Open the dashboard in your browser**
   - Navigate to http://localhost:8080/dashboard/
   - You should see the Traefik dashboard with routing information

### Troubleshooting

- If you encounter issues with IngressRoute resources not being recognized, ensure the CRDs are installed:
  ```bash
  kubectl get crd | grep traefik
  ```

- To check Traefik logs:
  ```bash
  kubectl logs -n traefik -l app.kubernetes.io/name=traefik
  ```