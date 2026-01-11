### Steps
1. Add the helm repo `helm repo add prometheus-community https://prometheus-community.github.io/helm-charts`
2. Install helm chart
    ```bash
    helm upgrade --install prometheus prometheus-community/prometheus \
    -f prometheus-values.yaml \
    -n monitoring
    ```

    > Note: You can safely ignore the Pod Security Policy warnings during installation. PSP is deprecated in Kubernetes 1.25+ and not needed for modern clusters.

    > You can also ignore the warning about pod security for node-exporter. It needs access to host resources (hostPath volumes, hostNetwork, hostPID) and the SYS_TIME capability to collect system metrics properly. These exceptions are expected and necessary for Node Exporter to function.

3. Apply the ingress file `kubectl apply -f ingress.yaml`
4. Log into the admin interface at prometheus.home.jasongodson.com

