---
title: Solving Docker Registry Authentication for Gitea Actions Runners
description: The journey from manual workflows to automated Docker authentication for self-hosted Gitea Actions runners in Kubernetes, and why imagePullSecrets don't solve everything.
date: 2025-10-24
tags:
  - gitea
  - kubernetes
  - docker
  - ci-cd
  - homelab
layout: post.njk
---

While working on an automated Proxmox restart workflow with Gitea Actions, I ran into a frustrating problem: **my runners couldn't pull private Docker images from my Gitea registry without manual intervention**. Every time a new pod started and I wanted to use a workflow with my custom runner image, I had to manually run a "docker login" workflow first.

This seemed like it should be a solved problem. After all, Kubernetes has `imagePullSecrets` for exactly this purpose, right? Well, not quite...

## The Setup: Gitea Registry with Custom Runner Images

First, some context on the setup. Gitea has a built-in Docker registry, which I'm using to host custom runner images:

1. **Created a `homelab` organization** in Gitea for shared infrastructure
2. **Created an `actions-runner` repository** under the homelab org (this serves as the package namespace)
3. **Built and pushed a custom runner image** with homelab-specific tools:
   ```bash
   docker build -t gitea.home.jasongodson.com/homelab/actions-runner:latest .
   docker push gitea.home.jasongodson.com/homelab/actions-runner:latest
   ```

The image is hosted at: `https://gitea.home.jasongodson.com/homelab/-/packages/container/actions-runner/`

This lets me customize the runner environment with tools like kubectl, helm, ansible, and other utilities specific to my homelab workflows.

## The Problem: Multiple Docker Contexts

My Gitea Actions runners use two different labels:
- `homelab-latest:docker://gitea.home.jasongodson.com/homelab/actions-runner:latest` - Runs workflows in a custom Docker image
- `host-docker:host` - Runs workflows directly on the host's Docker daemon. I use this for bulding images.

When a workflow tried to use the `homelab-latest` label, I'd get this error:

```bash
Error response from daemon: unauthorized: reqPackageAccess
```

{% image "./src/assets/images/gitea-ar-docker-permissions.png", "Gitea runner failure", "(min-width: 768px) 600px, 100vw" %}

The runner was deployed as a Kubernetes StatefulSet with a Docker-in-Docker (`dind`) sidecar container. I initially thought adding an `imagePullSecret` to the pod spec should cover this.

**Spoiler:** That didn't work.

## Understanding the Architecture

To understand why, let's look at what's actually happening:

```
Kubernetes Pod: gitea-actions-act-runner-0
├── act-runner container (executes workflows)
│   ├── Connects to Docker via TCP: tcp://127.0.0.1:2376
│   └── Uses Docker client library to pull images
└── dind container (Docker-in-Docker daemon)
    └── Runs dockerd, listens on tcp://0.0.0.0:2376
```

The `act-runner` container doesn't have Docker installed - it uses a **Docker client library** to connect to the `dind` container's Docker daemon via TCP with TLS authentication.

Here's where it gets interesting:
- **Kubernetes `imagePullSecrets`** only help Kubernetes pull the runner **pod's container image**
- They do **nothing** for images that `act-runner` pulls via the Docker API when executing workflows
- The Docker client library reads credentials from `~/.docker/config.json` in the `act-runner` container
- But we never created that file!

## Failed Attempt #1: imagePullSecrets

```yaml
spec:
  imagePullSecrets:
    - name: gitea-registry-creds
```

**Result:** ❌ Didn't help. Workflows still couldn't pull the homelab-latest image.

**Why it failed:** `imagePullSecrets` only helps Kubernetes pull the pod's container images, not images that the workflow executor pulls via the Docker API.

## Failed Attempt #2: Mounting Docker Config

I tried mounting a pre-configured `~/.docker/config.json` into the act-runner container:

```yaml
volumeMounts:
  - name: docker-config
    mountPath: /root/.docker
```

**Result:** ❌ Still didn't work for `host-docker` mode.

**Why it failed:** The `host-docker` label makes workflows run on the **host's Docker daemon**, not the container's Docker daemon. Config mounts only affect the container filesystem.

## Failed Attempt #3: Helm Chart Patching with Lifecycle Hook

I tried patching the Helm chart to inject a postStart lifecycle hook that would run `docker login` when the container starts:

```yaml
lifecycle:
  postStart:
    exec:
      command:
        - /bin/sh
        - -c
        - echo "$REGISTRY_PASSWORD" | docker login $REGISTRY_URL -u $REGISTRY_USERNAME --password-stdin
```

**Result:** ❌ Pods went into `CrashLoopBackOff` with `FailedPostStartHook`.

**Why it failed:** While `kubectl describe pod` showed the hook failed, there was no way to see the actual error output from the docker login command. postStart hooks are **blocking** - if they fail or timeout, Kubernetes kills the container. The Docker daemon timing during startup is unpredictable, which likely caused intermittent failures, but without access to the hook's stdout/stderr, debugging was nearly impossible. Additionally, maintaining Helm chart patches adds complexity to deployments and chart updates.

## The Solution: CronJob-Based Authentication

After these failed attempts, I realized I needed a solution that:
1. Creates the Docker config in the `act-runner` container (where the Docker client library runs)
2. Doesn't block pod startup
3. Automatically refreshes credentials periodically
4. Can recover from failures
5. Doesn't require modifying the Helm chart

Enter the CronJob approach:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: gitea-runner-docker-login
  namespace: gitea
spec:
  schedule: "0 * * * *"  # Every hour
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: gitea-runner-docker-login
          containers:
          - name: docker-login
            image: alpine/k8s:1.32.9
            command:
              - /bin/sh
              - -c
              - |
                echo "🔐 Starting Docker login refresh..."
                
                PODS=$(kubectl get pods -n gitea \
                  -l app.kubernetes.io/name=actions-act-runner \
                  -o jsonpath='{.items[*].metadata.name}')
                
                for POD in $PODS; do
                  # Create .docker config in act-runner container
                  kubectl exec -n gitea "$POD" -c act-runner -- sh -c \
                    "mkdir -p /root/.docker && \
                     echo '{\"auths\":{\"'$REGISTRY_URL'\":{\"auth\":\"'$(echo -n "$REGISTRY_USERNAME:$REGISTRY_PASSWORD" | base64)'\"}} }' \
                     > /root/.docker/config.json"
                done
            env:
              - name: REGISTRY_URL
                value: "gitea.home.jasongodson.com"
              - name: REGISTRY_USERNAME
                valueFrom:
                  secretKeyRef:
                    name: gitea-docker-registry-creds
                    key: username
              - name: REGISTRY_PASSWORD
                valueFrom:
                  secretKeyRef:
                    name: gitea-docker-registry-creds
                    key: password
```

This approach:
- ✅ Runs every hour to keep credentials fresh
- ✅ Creates the config file in the `act-runner` container (where the Docker client library reads it)
- ✅ Doesn't block pod startup
- ✅ Self-healing (retries every hour if it fails)
- ✅ Uses RBAC to securely exec into pods

## RBAC Configuration

The CronJob needs permissions to list pods and exec into them:

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gitea-runner-docker-login
  namespace: gitea
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: gitea-runner-docker-login
  namespace: gitea
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
  - apiGroups: [""]
    resources: ["pods/exec"]
    verbs: ["create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: gitea-runner-docker-login
  namespace: gitea
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: gitea-runner-docker-login
subjects:
  - kind: ServiceAccount
    name: gitea-runner-docker-login
    namespace: gitea
```

## Integration with Deployment Script

I integrated the CronJob into my existing [`deploy-runners.sh` script](https://github.com/jgodson/homelab/blob/main/k8s-configs/gitea/deploy-runners.sh):

```bash
deploy_docker_login_cronjob() {
    log_info "Deploying Docker login CronJob..."
    
    if [ -f "$SCRIPT_DIR/docker-login-cronjob.yaml" ]; then
        kubectl apply -f "$SCRIPT_DIR/docker-login-cronjob.yaml"
        log_success "Docker login CronJob deployed"
    else
        log_warning "docker-login-cronjob.yaml not found, skipping..."
    fi
}

main() {
    check_prerequisites
    ensure_namespace
    update_helm_chart
    deploy_release
    deploy_docker_login_cronjob  # ← New step
    show_status
    cleanup
}
```

Now when I deploy the runners, the CronJob is automatically created and configured.

## Testing the Solution

To test manually before waiting for the hourly schedule:

```bash
# Create a manual job from the CronJob
kubectl create job -n gitea test-login \
  --from=cronjob/gitea-runner-docker-login

# Watch the logs
kubectl logs -n gitea -l job-name=test-login -f
```

Output:
```bash
🔐 Starting Docker login refresh for all runner pods...
📦 Refreshing Docker login on pod: gitea-actions-act-runner-0
✅ Successfully configured Docker auth for gitea-actions-act-runner-0
📦 Refreshing Docker login on pod: gitea-actions-act-runner-1
✅ Successfully configured Docker auth for gitea-actions-act-runner-1
🎉 Docker login refresh complete!
```

Verify the config was created:
```bash
kubectl exec -n gitea gitea-actions-act-runner-0 -c act-runner -- \
  cat /root/.docker/config.json
```

Result:
```json
{
  "auths": {
    "gitea.home.jasongodson.com": {
      "auth": "..."
    }
  }
}
```

## The Workflow Now Works!

After deploying the CronJob, my workflows can now pull private images automatically:

{% image "./src/assets/images/gitea-ar-docker-permissions-fixed.png", "Gitea runner failure", "(min-width: 768px) 600px, 100vw" %}

No more manual `docker-login` workflow needed!

## Key Takeaways

1. **imagePullSecrets aren't a silver bullet** - They only help Kubernetes pull pod images, not images that your application pulls via the Docker API

2. **Understand your architecture** - In my case, `act-runner` uses a Docker client library that reads from `~/.docker/config.json`. The solution had to create that file in the `act-runner` container, not the `dind` container where dockerd runs. Putting credentials in the `dind` container didn't help because the Docker client runs in act-runner.

3. **Lifecycle hooks are difficult to debug** - postStart hooks block pod startup and can cause crashes if they fail, but Kubernetes doesn't capture their stdout/stderr. You'll see that the hook failed in events, but not why. This makes debugging nearly impossible for operations that depend on timing or external services.

4. **CronJobs are resilient** - Running authentication as a separate, periodic job is more reliable than tying it to container lifecycle. It's self-healing and doesn't block startup.

5. **kubectl exec is powerful** - Sometimes the best solution is a simple script that execs into containers and does what needs to be done.

## Files and Configuration

You can find all the configuration files in my [homelab repository](https://github.com/jgodson/homelab):

- [`k8s-configs/gitea/docker-login-cronjob.yaml`](https://github.com/jgodson/homelab/blob/main/k8s-configs/gitea/docker-login-cronjob.yaml) - The CronJob definition
- [`k8s-configs/gitea/deploy-runners.sh`](https://github.com/jgodson/homelab/blob/main/k8s-configs/gitea/deploy-runners.sh) - Deployment script with CronJob integration
- [`k8s-configs/gitea/actions-runner-values.yaml`](https://github.com/jgodson/homelab/blob/main/k8s-configs/gitea/actions-runner-values.yaml) - Helm values for the runners

#### Update (October 25, 2025)

The Proxmox automated restart post is up! Check out [Automating Proxmox Host Restarts with Gitea Actions](/blog/proxmox-restart-automation) for the full story.

---

Have you encountered similar issues with Docker authentication in action runners? Let me know how you solved it - I'm always interested in learning about alternative approaches!
