---
title: "Battle of the Brains: A One‑Evening Jackbox‑Style Math Game"
description: Building a Jackbox-style math party game in one evening for my kids, using Vite, TypeScript, and a reused WebSocket backend.
date: 2026-01-11
tags:
  - gamedev
  - homelab
  - frontend
  - backend
  - educational
layout: post.njk
---

## Why I Built It
This project started as a simple goal: make math practice feel like a game show for my son and daughter. We've played [Jackbox Games](https://www.jackboxgames.com) as a family before and loved the energy, so that served as the main inspiration. They need repetition, but I wanted it to feel playful, competitive, and exciting instead of like homework. Since I already had a working multiplayer backend from my previous Godot game, [Treasure Takedown](/blog/godot-multiplayer-backend-portal/), I realized a new web‑based party game could piggyback on that foundation.

After just one evening and a morning of focused work, the outcome exceeded my expectations. It was genuinely fun to play, and the kids were into it.

## The Game Idea
**Battle of the Brains** is a Jackbox‑style, arcade‑game‑show quiz built around math questions.

The format:
- **Screen client** (TV/monitor) shows the game.
- **Controller clients** (phones) let players buzz and answer.
- First buzz wins the attempt.
- Correct answers earn points with a multiplier that increases after wrong answers.
- Wrong answers (or timeouts) **deduct points**.
- If nobody buzzes, the question is skipped and the answer is revealed.

It’s meant to feel loud, energetic, and competitive, with music, countdown ticks, and celebratory effects.

## Visual and Audio Direction
I wanted an arcade/game show vibe to try and keep the kids interested:
- Neon accents, big typography, high contrast.
- Animated countdowns and screen shake.
- Confetti and “flash” effects on correct answers.
- Skull + penalty pop on wrong answers.
- Background music and sound effects tailored to the game flow.

Audio was intentionally lightweight (synth‑style tones) and respects mobile autoplay restrictions — you have to click to enable sound.

## Gallery

{% slideshow %}
    src/assets/images/botb-landing.png, Landing Screen with Host/Join options
    src/assets/images/botb-room.png, Room Screen with code and settings
    src/assets/images/botb-controller-join.png, Controller Join Screen
    src/assets/images/botb-question.png, Live Question with countdown
    src/assets/images/botb-controller-buzz.png, Controller Buzz Interface
    src/assets/images/botb-controller-answer.png, Controller Answer Interface
    src/assets/images/botb-score-reveal.png, Score Reveal
    src/assets/images/botb-gameover.png, Game Over Screen
{% endslideshow %}

## Architecture (Based on the Previous Godot Game)
The Go backend originally powered a Godot game ([Treasure Takedown](/blog/godot-multiplayer-backend-portal/)) with WebSocket connections, file serving, room handling, and admin and metrics endpoints. Rather than rewrite everything, I:

- **Kept the existing websocket + room infrastructure.**
- Built a **new game handler**: `battle-of-the-brains`.
- Added a **new web frontend** (Vite + TypeScript).
- Updated the backend to serve the frontend assets instead of game files.

That let me move fast while still keeping the original networking ideas intact (ticketed joins, admin UI, etc.).

### Key Backend Points
- Websocket server is authoritative: question generation, scoring, state machine.
- Rooms + players are managed in memory.
- JSON schema with `{type, payload}` messages.
- One‑time tickets + JWT for join/auth flow.
- Admin endpoints (`/admin`, `/admin/stats`, `/admin/metrics`) preserved and repurposed.
- Metrics use a legacy naming format so they plug into my existing monitoring.

### Game State Machine
Each question flows through:
1) Countdown
2) Question (buzz window)
3) Answering (locked to active player)
4) Reveal
5) Next question / Game over

### Anti-spam & Reconnection
Tickets are short‑lived (TTL) and **consumed on use**, but players can resume mid‑game by requesting a new ticket with their `player_id`.

## Design Choice: Math, but Not Hardcoded
The initial content is math questions, but the name and structure don’t lock the game into math. It can expand to other mini‑games or question types later without needing a total rewrite.

## Remote Play Option
To support remote play (without a shared screen), I added a setting to **show questions on devices**. When disabled, the server never sends question text to controllers — preventing cheating by default. When enabled, it makes remote play possible.

## Deployment
The app is designed to run behind a subpath [`https://play.jasongodson.com/battle-of-the-brains`](https://play.jasongodson.com/battle-of-the-brains).

The backend serves the built frontend and the websocket endpoint under the same base path. Kubernetes manifests and a single Dockerfile handle build + deployment for a homelab setup.

## What Surprised Me
Even without fancy assets, this felt like a real party game quickly. The combination of sounds, countdown tension, and score swings made math feel… dramatic.

I wasn't sure what to expect, but when my daughter said it was actually fun, it made it worth it.

## Final Thoughts
This was a small, focused sprint that delivered more joy than expected. The speed at which I could build this using AI really amplified the fun factor of the development process itself. It’s the kind of project that reminded me why I like building games: a good idea, a tight loop, and a little polish can turn practice into play.
