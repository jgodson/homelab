### Steps
- Create user for ceph on promox node

```bash
ceph auth get-or-create client.kubernetes \
  mon 'profile rbd' \
  mgr 'profile rbd' \
  osd 'profile rbd pool=ceph'
```

- Create namespace `kubectl create namespace "ceph-csi-rbd"`
- Create secret in kubernetes from 1Password Kubernetes vault (`Ceph secret`)
- Set PodSecurity level to privileged (required for Ceph CSI) `kubectl label namespace ceph-csi-rbd pod-security.kubernetes.io/enforce=privileged`
- Apply helm chart

```bash
helm install ceph-csi-rbd ceph-csi/ceph-csi-rbd \
-f values.yaml \
-n ceph-csi-rbd
```

- Check to make sure all pods are up and storage class is created

```bash
kubectl get pods -n ceph-csi-rbd -w
kubectl get sc
```

- Create a test PVC

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ceph-test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: ceph-rbd
EOF
```

- Check if that is bound `kubectl get pvc ceph-test-pvc`
- Deploy a test pod using the PVC

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ceph-test-pod
spec:
  containers:
    - name: test
      image: busybox
      command: ["/bin/sh", "-c", "echo 'Hello from Ceph!' > /data/test.txt && sleep 3600"]
      volumeMounts:
        - mountPath: /data
          name: ceph-volume
  volumes:
    - name: ceph-volume
      persistentVolumeClaim:
        claimName: ceph-test-pvc
EOF
```

## Troubleshooting

### Testing connection to ceph pool

Test the connection to the pool with a container
`kubectl run -n ceph-csi-rbd ceph-tester --image=quay.io/ceph/ceph:v19 -- sleep infinity`

`kubectl wait --for=condition=Ready pod/ceph-tester -n ceph-csi-rbd`

`$userId` is the name of the client and `$userKey` below are what you would get from `ceph auth get client.kubernetes`, not from kubernetes secrets.

```
kubectl exec -it -n ceph-csi-rbd ceph-tester -- bash -c "
echo 'Testing direct Ceph connection with CSI credentials'
echo '[global]' > /etc/ceph/ceph.conf
echo 'mon host = $MONIP:6789' >> /etc/ceph/ceph.conf

# This is the key correction - proper keyring format
echo '[client.kubernetes]' > /etc/ceph/keyring
echo 'key = $userKey' >> /etc/ceph/keyring

ceph -c /etc/ceph/ceph.conf --id $userID --keyring /etc/ceph/keyring -s
echo 'Trying to list the pool'
rados -c /etc/ceph/ceph.conf --id $userID --keyring /etc/ceph/keyring -p ceph ls | grep csi
"
```

To list the same on the proxmox node `rados -p ceph ls | grep csi` or `rbd ls -p ceph | grep csi`.

### Finding and Cleaning Up CSI Volumes in Ceph

#### Find the Volume ID Associated with Your Stuck PV
`kubectl get pv`
`kubectl describe pv <pv-name>`

Look for the `VolumeAttributes` field - it should contain an `imageName` that matches one of the entries below.

#### Complete Cleanup Process
1. First try restarting the provisioners

    `kubectl delete pods -n ceph-csi-rbd -l component=provisioner`

    If that doesn't help after a few minutes, continue with these steps.    

1. Clean up Volume

    On the Proxmox node, run `rbd ls -p ceph | grep <imageName>` to see if the volume is there.

    If so, run `rbd rm -p ceph <imageName>`

1. Clean up Orphaned Metadata

    On the Proxmox node, run `rados -p ceph ls | grep <last part of imageName (excludes csi-volume-)>`

    If so, run `rados -p ceph rm csi.volume.<last part of imageName (excludes csi-volume-)>` to delete it.

1. Patch the PV to remove finalizers

    `kubectl patch pv <pv-name> -p '{"metadata":{"finalizers":null}}' --type=merge`

1. Force delete the PV

    `kubectl delete pv <pv-name> --force --grace-period=0`

1. If it's stil stuck, restart the provisioner pods

    `kubectl delete pods -n ceph-csi-rbd -l component=provisioner`