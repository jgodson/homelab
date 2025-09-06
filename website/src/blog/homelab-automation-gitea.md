---
title: Setting Up Gitea for Homelab Automation
description: How I automated my homelab maintenance tasks using Gitea, Ansible, and self-hosted runners.
date: 2025-09-06
tags:
  - automation
  - ansible
  - gitea
  - homelab
layout: post.njk
---

## The Problem

Even though it’s only a homelab, there’s a lot of maintenance that goes into it — keeping things up to date, clearing old logs, and more. In this post, I’ll share how I automated these tasks using Gitea, Ansible, and self-hosted runners.

## Why Automate Homelab Maintenance?

Let’s face it: maintaining a homelab can feel like a full-time job. There’s always something to update, clean up, or troubleshoot. Sure, you can use cron jobs or bash scripts, but I wanted something more centralized and elegant. Enter **Ansible**.

Ansible is a game-changer. Instead of copying scripts to each machine and scheduling them with Cron or systemd services, I can:

- Write a playbook once.
- Run it from my machine.
- Let Ansible handle the SSH connections, task execution, and logging.

But there was still one problem: scheduling. Running playbooks from my MacBook wasn’t ideal—it only works when the laptop is awake. A dedicated VM for scheduling tasks? Too much maintenance. I needed something better.

## Exploring CI/CD Options

### GitHub

I’ve always loved **GitHub Actions**. They’re versatile, reliable, and great for CI/CD. You can use them for anything — collecting metrics, testing connectivity, running integration tests, you name it. But my homelab isn’t exposed to the public internet, so GitHub Actions wasn’t an option without some networking gymnastics (ie: Cloudflare tunnels). The alternative to avoid public internet — **self hosting at home**.

### GitLab

My first thought was GitLab. It’s a powerhouse with CI/CD and container registry capabilities. But after struggling to get it running, I realized it wasn’t the right fit. The setup was complex, and while I did end up with Postgres running in Kubernetes (a win for future projects), GitLab itself felt like overkill.

### Discovering Gitea

During my struggles to get GitLab running, someone suggested **Gitea**. Gitea is a lightweight GitHub alternative and I originally wrote it off thinking it didn't have built in CI/CD or container registries. Turns out, it does — and, as a bonus, with far less resource usage than GitLab. After this research, I was sold.

## Setting Up Gitea

Deploying Gitea was refreshingly simple. I used the offical Helm chart, tweaked the values, and had it up and running in no time. There were a few hiccups (like needing to use HTTP instead of SSH due to my Caddy proxies), but overall, it was a breeze compared to GitLab.

### Adding Self-Hosted Runners

Although there was nothing available via Helm itself, Gitea’s official repository provided a Helm chart for self-hosted runners. After creating a runner token in Gitea, I deployed the runners. These little workhorses now execute my Ansible playbooks on a schedule. It’s like having my own private GitHub Actions setup—pretty neat, right?

## Automating Homelab Tasks

With Gitea and the runners in place, I turned my attention to automation. My first targets? The usual suspects:

1. **Ubuntu Updates**
2. **Docker Updates**

### Adding Docker Cleanup

When I first tried running a simple ansible check for the docker_hosts I configured, one host complained of not being able to create a temporary directory. This was weird since the setup was the same as the other hosts. I logged in to investigate and discovered the disk was at 100% usage and the culprit was 12GB of old, unused Docker images.

After manually cleaning up the mess, I realized this wasn’t a one-off issue. Docker has a way of quietly hoarding images like a digital packrat. So, I wrote a playbook to automate the cleanup process. Here’s what it does:

- Identifies and removes dangling images and build caches.
- Prunes unused volumes (though not by default).
- Checks for stopped containers (in case bad things happened).

It’s a simple solution and there should be no more surprise disk-full errors.

### The Docker Update Playbook

After that, it was time to tackle what I originally set out to do - updates! I created some dedicated SSH keys for the homelab hosts, set that as an actions secret, and got started. Here’s what I came up with for updating Docker containers:

```yaml
{% raw %}
- name: Update Docker Containers
  hosts: docker_hosts
  become: true
  gather_facts: true

  tasks:
    - name: Get list of running containers
      ansible.builtin.shell: |
        set -o pipefail
        sudo docker ps --format \
          "table {{ '{{' }}.Names{{ '}}' }}\t{{ '{{' }}.Image{{ '}}' }}\t{{ '{{' }}.Status{{ '}}' }}"
      args:
        executable: /bin/bash
      register: container_list
      changed_when: false

    - name: Display current containers
      ansible.builtin.debug:
        msg: "Container list: {{ container_list.stdout_lines }}"

    - name: Show detailed image information before updates
      ansible.builtin.shell: |
        set -o pipefail
        echo "=== Current Docker Images with Tags ==="
        fmt="table {{ '{{' }}.Repository{{ '}}' }}\t{{ '{{' }}.Tag{{ '}}' }}\t{{ '{{' }}.ID{{ '}}' }}\t"
        fmt="${fmt}{{ '{{' }}.CreatedAt{{ '}}' }}\t{{ '{{' }}.Size{{ '}}' }}"
        sudo docker images --format "$fmt" | head -10
        echo ""
        echo "=== Running Containers with Image Info ==="
        sudo docker ps --format \
          "table {{ '{{' }}.Names{{ '}}' }}\t{{ '{{' }}.Image{{ '}}' }}\t{{ '{{' }}.Status{{ '}}' }}\t{{ '{{' }}.CreatedAt{{ '}}' }}"
      args:
        executable: /bin/bash
      register: image_info_before
      changed_when: false

    - name: Display image information
      ansible.builtin.debug:
        msg: "{{ image_info_before.stdout_lines }}"

    - name: Update Docker Compose services
      ansible.builtin.shell: |
        set -o pipefail
        cd "{{ item }}"
        echo "=== Updating compose services in $(pwd) ==="

        # Get current image IDs before update
        echo "Current images:"
        sudo docker compose images
        before_images=$(sudo docker compose images --format "{{ '{{' }}.Service{{ '}}' }}:{{ '{{' }}.ID{{ '}}' }}" 2>/dev/null || echo "")

        # Pull any registry images (will skip locally built ones automatically)
        echo "Pulling registry images..."
        sudo docker compose pull || echo "Pull completed (some images may be locally built)"

        # Build any services that have build contexts (handles Dockerfiles)
        echo "Building any local images..."
        sudo docker compose build --pull || echo "Build completed (no build contexts or build failed)"

        # Get image IDs after update
        echo "Images after pull/build:"
        sudo docker compose images
        after_images=$(sudo docker compose images --format "{{ '{{' }}.Service{{ '}}' }}:{{ '{{' }}.ID{{ '}}' }}" 2>/dev/null || echo "")

        # Check if any images changed
        if [[ "$before_images" != "$after_images" ]]; then
          echo "Images changed - restarting services with new images..."
          sudo docker compose up -d
        elif [[ "${{ force_recreate | default(false) | bool }}" == "True" ]]; then
          echo "Force recreate requested - recreating all containers..."
          sudo docker compose up -d --force-recreate
        else
          echo "No image changes detected and no force recreate - skipping restart"
        fi

        echo "=== Update complete for $(pwd) ==="
      args:
        executable: /bin/bash
      loop: "{{ docker_compose_dirs | default([]) }}"
      when: docker_compose_dirs is defined and docker_compose_dirs | length > 0
      register: compose_results
      changed_when: >
        'Images changed or force recreate requested - restarting services' in compose_results.stdout or
        'Recreated' in compose_results.stderr or
        'Started' in compose_results.stderr or
        'Created' in compose_results.stderr

    - name: Debug compose results (for troubleshooting)
      ansible.builtin.debug:
        msg: |
          Compose results for {{ item.item }}:
          stdout: {{ item.stdout }}
          stderr: {{ item.stderr }}
          changed: {{ item.changed }}
      loop: "{{ compose_results.results | default([]) }}"
      when: compose_results.results is defined

    - name: Clean up unused images
      ansible.builtin.command: sudo docker image prune -f
      register: cleanup_result
      changed_when: "'deleted' in cleanup_result.stdout.lower()"

    - name: Show final image and container status
      ansible.builtin.shell: |
        set -o pipefail
        echo "=== Final Container Status ==="
        sudo docker ps --format \
          "table {{ '{{' }}.Names{{ '}}' }}\t{{ '{{' }}.Image{{ '}}' }}\t{{ '{{' }}.Status{{ '}}' }}\t{{ '{{' }}.CreatedAt{{ '}}' }}"
        echo ""
        echo "=== Updated Images ==="
        fmt="table {{ '{{' }}.Repository{{ '}}' }}\t{{ '{{' }}.Tag{{ '}}' }}\t{{ '{{' }}.ID{{ '}}' }}\t"
        fmt="${fmt}{{ '{{' }}.CreatedAt{{ '}}' }}\t{{ '{{' }}.Size{{ '}}' }}"
        sudo docker images --format "$fmt" | head -10
      args:
        executable: /bin/bash
      register: final_status
      changed_when: false

    - name: Display final status
      ansible.builtin.debug:
        msg: "{{ final_status.stdout_lines }}"

    - name: Display update summary
      ansible.builtin.debug:
        msg: |
          Docker Compose Update Summary:
          - Compose services updated: {{ (compose_results.results | default([])) | selectattr('changed') | list | length }}
          - Total directories processed: {{ docker_compose_dirs | default([]) | length }}
          - Force recreate enabled: {{ force_recreate | default(false) }}
          - Image cleanup: {{ cleanup_result.changed | default(false) }}
{% endraw %}
```

### Scheduling with Gitea Actions

After getting the playbook working, it was time to make sure I didn’t have to keep running it manually. Here’s the Gitea actions workflow file that I set up to run updates daily.

```yaml
{% raw %}
name: Docker Container Updates
on:
  schedule:
    # Run every day at 7 AM
    - cron: '0 7 * * *'
  workflow_dispatch:
    inputs:
      target_hosts:
        description: 'Target hosts (default: all docker_hosts)'
        required: false
        default: 'docker_hosts'
      force_recreate:
        description: 'Force recreate all containers'
        type: boolean
        default: false
      docker_compose_dirs:
        description: 'Docker Compose directories (comma-separated, e.g. /opt/app1,/opt/app2)'
        required: false
        default: ''

jobs:
  docker-updates:
    runs-on: homelab-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup SSH keys
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.HOMELAB_SSH_KEY }}" > ~/.ssh/homelab_key
          chmod 600 ~/.ssh/homelab_key
          
          # Disable strict host key checking for homelab automation
          echo "Host *" >> ~/.ssh/config
          echo "  StrictHostKeyChecking no" >> ~/.ssh/config
          echo "  UserKnownHostsFile /dev/null" >> ~/.ssh/config
          chmod 600 ~/.ssh/config
          
      - name: Lint playbook
        run: |
          cd ansible
          ansible-lint playbooks/docker-updates.yml
          
      - name: Check Docker hosts connectivity
        run: |
          cd ansible
          ansible ${{ github.event.inputs.target_hosts || 'docker_hosts' }} -m ping
        env:
          ANSIBLE_HOST_KEY_CHECKING: false
          
      - name: Pre-update container inventory
        run: |
          cd ansible
          echo "=== Container Status Before Updates ==="
          ansible ${{ github.event.inputs.target_hosts || 'docker_hosts' }} \
            -m shell -a "echo 'Host: '\$(hostname) && sudo docker ps --format 'table {{ '{{' }}.Names{{ '}}' }}\t{{ '{{' }}.Image{{ '}}' }}\t{{ '{{' }}.Status{{ '}}' }}'" \
            | sed 's/SUCCESS =>/\n--- Host:/g'
        env:
          ANSIBLE_HOST_KEY_CHECKING: false
          
      - name: Update Docker containers
        run: |
          cd ansible
          
          # Build extra vars based on inputs
          extra_vars=""
          if [[ "${{ github.event.inputs.force_recreate }}" == "true" ]]; then
            extra_vars="$extra_vars force_recreate=true"
          fi
          if [[ -n "${{ github.event.inputs.docker_compose_dirs }}" ]]; then
            # Convert comma-separated list to JSON array
            compose_dirs='[${{ github.event.inputs.docker_compose_dirs }}]'
            compose_dirs=$(echo "$compose_dirs" | sed 's/,/","/g' | sed 's/\[/["/' | sed 's/\]/"]/')
            extra_vars="$extra_vars docker_compose_dirs=$compose_dirs"
          fi
          
          ansible-playbook playbooks/docker-updates.yml \
            --limit ${{ github.event.inputs.target_hosts || 'docker_hosts' }} \
            ${extra_vars:+--extra-vars "$extra_vars"}
        env:
          ANSIBLE_HOST_KEY_CHECKING: false
          
      - name: Post-update container inventory
        if: success() || failure()
        run: |
          cd ansible
          echo "=== Container Status After Updates ==="
          ansible ${{ github.event.inputs.target_hosts || 'docker_hosts' }} \
            -m shell -a "echo 'Host: '\$(hostname) && sudo docker ps --format 'table {{ '{{' }}.Names{{ '}}' }}\t{{ '{{' }}.Image{{ '}}' }}\t{{ '{{' }}.Status{{ '}}' }}'" \
            | sed 's/SUCCESS =>/\n--- Host:/g'
        env:
          ANSIBLE_HOST_KEY_CHECKING: false
          
      - name: Generate update report
        if: success() || failure()
        run: |
          echo "## Docker Compose Update Report"
          echo "- Target: ${{ github.event.inputs.target_hosts || 'docker_hosts' }}"
          echo "- Force Recreate: ${{ github.event.inputs.force_recreate || 'false' }}"
          echo "- Compose Dirs: ${{ github.event.inputs.docker_compose_dirs || 'none specified (will use inventory defaults)' }}"
          echo "- Status: ${{ job.status }}"
          echo "- Time: $(date)"
{% endraw %}
```

As you can see, I set these as scheduled workflows, but always have the option of manually running them too. The `workflow_dispatch` trigger helps a lot with testing — it took several tries to get these actions working. The downside of working with actions is that you need to commit and push every change, so it slows down the trial and error cycle a bit. On the bright side, pushes to my local git repository are super fast! The runners also pick things up and start super quickly.

{% image "./src/assets/images/gitea-actions-run.png", "Actions runner timings", "(min-width: 768px) 600px, 100vw" %}

## Conclusion

Setting up Gitea for homelab automation has been a game-changer. It’s lightweight, easy to configure, and integrates seamlessly with Ansible. With self-hosted runners, I now have a private CI/CD system tailored to my homelab’s needs.

In future posts, I’ll dive deeper into container registries and other more advanced automation tasks. Stay tuned!