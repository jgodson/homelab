### Steps
1. Add the helm repo `helm repo add traefik https://traefik.github.io/charts`
1. Install the chart.
    ```
    helm install traefik traefik/traefik \
    -n traefik \
    --values values.yaml \
    --create-namespace
    ```

### Accessing the dashboard
1. Port forward to traefik to access the dashboard `kubectl port-forward -n traefik $(kubectl get pods -n traefik -l app.kubernetes.io/name=traefik -o name) 8080:8080`
1. Go to http://localhost:8080/dashboard/