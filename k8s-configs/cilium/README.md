# Cilium CNI

Replaces the default Flannel CNI to enable NetworkPolicy enforcement.

## Prerequisites

The Talos machine config must have `cluster.network.cni.name: none` to disable the built-in Flannel.

## Installation

```bash
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --namespace kube-system -f values.yaml
```

## Migration from Flannel

1. Apply the updated Talos machine config to all nodes:
   ```bash
   # Control Plane
   talosctl apply-config --nodes 192.168.1.30 --file ../talos-configs/controlplane-config.yaml

   # Workers
   talosctl apply-config --nodes 192.168.1.33 --file ../talos-configs/worker-config.yaml
   ```

2. Install Cilium:
   ```bash
   helm install cilium cilium/cilium --namespace kube-system -f values.yaml
   ```

3. Verify:
   ```bash
   cilium status
   cilium connectivity test
   kubectl get pods -n kube-system -l app.kubernetes.io/name=cilium
   ```

4. Rolling reboot nodes one at a time, verifying pod networking after each:
   ```bash
   talosctl reboot --nodes 192.168.1.30
   # Wait for node to be Ready, verify pods are running
   kubectl get nodes
   kubectl get pods -A
   # Repeat
   ```

## Important Notes

- After Cilium is installed, all existing NetworkPolicies will start being enforced
- Audit any existing NetworkPolicies across all namespaces before migration
