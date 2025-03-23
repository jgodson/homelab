1. Add the repo `helm repo add metallb https://metallb.github.io/metallb`
1. Create the namespace `kubectl apply -f namespace.yaml`
1. Install the chart
    ```
    helm install metallb metallb/metallb \
    -n metallb-system \
    -v values.yaml
    ```
1. Apply the extra configs `kubectl apply -f configs.yaml`


## Testing LoadBalancer Services on Talos

When using MetalLB on Talos Linux:

- Don't use ping to test LoadBalancer IPs (ICMP is blocked by default)
- Use application-level tests instead:
    ```bash
    curl http://<loadbalancer-ip>:<port>/
    ```

## IP Assignment Behavior
### One IP Per Service (Default)

Each LoadBalancer service gets its own unique IP from the pool:
- Service 1: Gets first available IP (e.g., 192.168.1.35)
- Service 2: Gets next available IP (e.g., 192.168.1.36)
- And so on...

### Multiple Ports Per Service

A single service can expose multiple ports on its assigned IP:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
    name: http
  - port: 443
    targetPort: 8443
    name: https
```

This service would get ONE IP but would be accessible on both ports 80 and 443.

### Requesting Specific IP's (Optional)
You can request specific IP's for a service by annotating the service.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: important-service
  annotations:
    metallb.universe.tf/loadBalancerIPs: 192.168.1.40
spec:
  type: LoadBalancer
  # ... rest of service definition
```

### Advanced: IP Sharing (Optional)
If you want multiple services to share an IP (for advanced use cases), you need to explicitly configure this with annotations:

```yaml
kind: Service
metadata:
  annotations:
    metallb.universe.tf/allow-shared-ip: sharing-key
```

Services with the same sharing-key can use the same IP, but this is not the default behavior.

### Troubleshooting

#### Show configured address pools

`kubectl get ipaddresspool -A`

#### Show configured l2 advertisements and the interfaces they use
`kubectl get l2advertisements -A`

#### Show services using metal lb addresses and what node they are on
`kubectl get servicel2statuses -A`