---
title: "Kube Manager: Building a Personal PaaS for My Homelab"
description: "Building my own Kubernetes deployment platform driven by Git webhooks to simplify deploying all my side projects, and what I learned about AI-assisted development along the way."
date: 2026-02-28
tags:
  - kubernetes
  - rust
  - homelab
  - ci-cd
  - automation
  - ai
  - devops
layout: post.njk
---

As time went on this year, I discovered I have a problem. I keep building side projects. A [multiplayer game backend](/blog/godot-multiplayer-backend-portal/), a [party math game](/blog/battle-of-the-brains/), a [Rails budget app](https://github.com/jgodson/budget-app-public), various homelab tools, and more keep accumulating. Each one needs to be containerized, pushed to a registry, deployed to Kubernetes, configured with ingress, secrets, environment variables, and monitored. For each new app, the deployment ritual looked roughly the same: write a Dockerfile, build it locally or in CI, push the image, write Kubernetes manifests, `kubectl apply`, check if it worked, repeat when something breaks.

I wanted something that would let me push code and have it show up running in my cluster or update without me doing anything else. Something purpose-built for my homelab that understood my workflow. So I built Kube Manager.

{% image "./src/assets/images/kube-manager-cluster-overview.png", "Kube Manager cluster overview showing CPU and memory usage", "(min-width: 768px) 600px, 100vw" %}

## What It Does

Kube Manager is a web application that sits between my Git repositories and Kubernetes clusters. It allows me to connect a cluster, point it at a repo, and configure how to build and deploy. From that point on, pushing code triggers the full pipeline automatically:

1. **Webhook arrives** from GitHub (or Gitea)
2. **BuildKit pod** spins up inside the cluster to build the container image
3. **Image gets pushed** to the configured registry (Gitea in my case)
4. **Deployment rolls out** using my chosen strategy: auto-generated manifests, my own YAML with variable substitution, or a Helm chart
5. **Real-time status** streams to the UI over WebSockets so I can watch it happen

It also handles the surrounding concerns: managing environment variables and secrets, provisioning databases (PostgreSQL via adding a new DB to my current CloudNativePG cluster or adding an entirely new cluster), configuring ingress, and provies a full UI for browsing pods, deployments, services, jobs, and everything else.

{% image "./src/assets/images/kube-manager-application-config.png", "Kube Manager application configuration page with repository, build, and deployment settings", "(min-width: 768px) 600px, 100vw" %}

## The Tech

The app is written in Rust using Axum as the web framework and Askama for compile-time checked HTML templates. PostgreSQL stores everything, with SQLx providing compile-time verified queries. The Kubernetes integration uses `kube-rs`, and the whole thing exposes Prometheus metrics at `/metrics` for Grafana dashboards.

One thing worth calling out: while the compilation safety of Rust and Askama is excellent (template typos become compiler errors, not runtime surprises), the developer experience for UI iteration is noticeably slower than something like Rails where changes hot-reload instantly. Every CSS tweak or template change requires a recompile. It's a trade-off I'd make again for a backend-heavy app like this, but it definitely slows down the frontend iteration cycle.

## Building It: The Four-Month Sprint

The first commit landed in early November 2025. Over the next four months, I put in 288 commits spanning cluster management, a full build pipeline, three deployment strategies, multi-cluster support, an API layer, and more.

The pace was intense. I was super focused on this in November as I built the foundations. December, I hardened the rough edges that I found while using it. January was quieter (the app was usable enough to just _use_ it), and February brought a focused push on the REST API (so I could get AI to do some of the work) and fixing some bugs with the GitOps features.

{% image "./src/assets/images/kube-manager-builds.png", "Build history showing kube-manager building itself", "(min-width: 768px) 600px, 100vw" %}

## AI-Assisted Development: The Honest Version

I built Kube Manager almost entirely with AI coding assistants, primarily Gemini CLI. I've [written before](/blog/sqlite-to-postgres-without-orm/) about the experience of letting AI make architectural decisions, but Kube Manager was a much larger undertaking and pushed that approach to its limits.

### The Good

The scope of this project was massive. AI unquestionably made it faster. Well-scoped tasks were resolved quickly and easily: "add this UI element," "fix these compilation errors," "implement this API endpoint." Gemini CLI with Pro-3 is quite good and for the price of the Google One subscription (which I can use for homelab storage backup too), it's been worth it. I've also used Codex and Claude during this time. All of them are impressive.

AI was also great at generating local development scripts. Having a solid local dev setup is critical for any project, and the tooling around that came together quickly.

### The Not-So-Good

Many things the AI marked as "done" were only partially implemented. I discovered every single one of these through manual testing, not through some automated safety net. In practice, it felt less like pair programming and more like reviewing someone else's broken code in an unfamiliar codebase, every single time. The testing loop was no different than writing-it-yourself development, except I hadn't written the code, so understanding _why_ something was broken took longer.

The security issues were the most concerning. I'm not a security expert, but discovering things like missing secure cookie flags and comments like `// Add encryption later` scattered through the codebase was alarming. These weren't subtle edge cases. They were fundamental security gaps that would have gone unnoticed without actually reading the code. "Vibe coding" without reviewing what was generated is genuinely risky for anything beyond throwaway prototypes.

Some tasks also needed a surprising amount of hand-holding and direction. The takeaway I keep coming back to: AI gets you far, fast, but the result is unlikely to be in good shape without thorough review. Treat AI-generated code exactly like you would a pull request from a junior developer. Read every line. I did let tests slide since this is a side project, but having them would have caught things earlier and provided more confidence when reviewing changes later. I suspect as the models get better and better, less and less manual review will need to be done, but it's not quite there yet. Or at least needs another pass with the AI focused on security should be done.

### The Loops

Several times, Gemini got stuck in a loop, repeating the same actions endlessly. This was more of a problem in VSCode's Copilot than the CLI. The Gemini CLI seems to have some built-in detection to break out of loops (though it doesn't always work), while VSCode either doesn't have this or lets it run much longer before stopping. This _was_ back in November and I haven't noticed this behaviour recently anymore.

{% image "./src/assets/images/gemini-ai-loop.png", "Gemini stuck in a loop reading the same files repeatedly", "(min-width: 768px) 400px, 100vw", "400px" %}

{% image "./src/assets/images/gemini-ai-loop-2.png", "Gemini stuck reasoning in circles about the same error", "(min-width: 768px) 400px, 100vw", "400px" %}

### The Instructions It Ignored

I prefer to handle git operations myself since AI assistants tend to commit every change after I mention it once, even before I've had a chance to check if things are finished. I added explicit instructions to my `GEMINI.md` file: only read git operations, no `git commit`, no `git push`. Gemini acknowledged the instructions and then committed anyway. When I asked why, it admitted it made a mistake and didn't follow the rules. It hasn't happened since, but it was a good reminder that these guardrails aren't guarantees.

## The Inception Moment

One of the milestones I was most excited about was deploying Kube Manager _with itself_. When I first attempted this, I needed to delete the existing deployment to start fresh. I couldn't remember if we had implemented cleanup logic yet. I asked the AI, and it confidently told me we hadn't and it was safe to delete.

It was not safe.

After deleting, I refreshed the page and got a 404. The cleanup code _did_ exist and it had torn down part of the application. At least Gemini admitted it was wrong. And luckily, the cleanup logic was basic enough that it only looked for resources matching `kube-manager-db` and `kube-manager-secrets`, so my encryption keys for the database survived. But it was a solid reminder not to trust AI assertions about your own codebase without checking yourself.

{% image "./src/assets/images/kube-manager-inception-complete.png", "Kube Manager deployment history showing itself deploying itself", "(min-width: 768px) 600px, 100vw" %}

Eventually the inception worked, and there's something deeply satisfying about watching Kube Manager deploy a new version of itself. The deployment history screenshot above shows exactly that: kube-manager building and deploying kube-manager for the first time successfully.

## The Commit History Tells a Story

If you ever want the unfiltered version of how a project really went, read the git log. Some highlights from mine:

- `builds actually seem to work` (the relief in that message)
- `fix helm deployment for reals?` (spoiler: not quite)
- `actually fix webhook selection hopefully`
- `so so many things`
- `fix a bunch of stuff`

The commit messages got a bit more professional over time, but the early ones are an honest record of the chaos.

## What I Learned

### ServiceAccounts and RBAC

The biggest technical learning was around Kubernetes ServiceAccounts and Role-Based Access Control. My initial approach required creating a ServiceAccount manually and pasting its token into Kube Manager through the UI. This works and is still the method for managing external clusters. But what I could have done for the cluster Kube Manager itself runs in is simply use the ServiceAccount that Kubernetes automatically creates for it. No token pasting needed. I'll probably refactor this at some point since it's cleaner, and another app I was working on (Issue to PR) already works this way since it was a simpler change there.

### Realistic Data Seeding

Something I didn't do for Kube Manager but wish I had: a realistic seed script. For my Rails budget app, I spent time building a proper seed script with realistic data, and it was incredibly useful for UI development. With Kube Manager (and Issue to PR), I just run the app locally, try things out, and populate data manually. It works, but it's inefficient. Investing in realistic data seeding early is worth the time.

### AI Tools Make Different Choices

One interesting observation while asking the CLI tools to edit a file outside the current working directory, Gemini CLI and OpenAI's Codex chose completely different strategies. Codex wrote a Python script to make the edits. Gemini created a new temp file, used `mv` to overwrite the original, then deleted the temp file. Same task, same codebase, fundamentally different approaches. It's a reminder that these tools have their own "personalities" in how they solve problems. The CLI Sandboxes and models have evolved consierably since and there are much better ways to do this.

## Brief Mention: Issue to PR

Alongside Kube Manager, I also built Issue to PR, a tool that uses AI models (local or API-based) to automatically triage GitHub/Gitea issues, generate pull requests, and review code. The concepts were similar to commercial tools like Jules (which I didn't know about when I started, maybe didn't even exist yet): isolated containers, locked-down networks, automated code generation.

It's a neat idea, but I've found that local models slow down significantly as context grows, and without a capable model the output quality drops quickly. Even with something good like Jules, my preferred way of developing is still being the orchestrator myself. Pulling a PR, checking changes, then commenting on an issue for revisions is too slow compared to directing an AI assistant in real-time. I've paused a large refactor on it for now.

## Dashboards Bring Joy

With both apps running and exposing `/metrics` endpoints, one of the best parts is seeing them come to life in Grafana. Build durations, deployment success rates, webhook processing times, pod metrics... I genuinely enjoy watching dashboards populate with real data. It was one of the main reasons I made sure both apps had Prometheus metrics from the start.

{% image "./src/assets/images/kube-manager-grafana-dashboard.png", "Grafana dashboard showing Kube Manager metrics, request latency, builds, and deployments", "(min-width: 768px) 600px, 100vw" %}

## Where It Stands Today

Kube Manager handles my day-to-day deployment workflow now. I push code, webhooks fire, builds run inside the cluster, and deployments roll out. The app supports multiple clusters, multiple Git providers, three deployment strategies (managed, manifests, Helm), database provisioning, a full REST API, and real-time monitoring. It's not a commercial product, but it does what I need: makes deploying all my side projects to Kubernetes simple and automated.

The whole experience, including the AI-assisted development, the four months of intense building, the security scares, the helm debugging marathons, the inception moment, taught me more about Kubernetes and CI/CD than any tutorial could. Sometimes the best way to learn a system is to build the tooling around it.

{% image "./src/assets/images/kube-manager-applications-list.png", "Kube Manager applications list showing multiple deployed apps and recent build status", "(min-width: 768px) 600px, 100vw" %}
