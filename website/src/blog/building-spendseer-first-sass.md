---
title: "From Homelab Tool to SaaS: What I Learned Launching Spendseer"
description: What I learned turning a homelab budgeting tool into my first paid SaaS, and why the post itself got delayed.
date: 2026-04-14
tags:
  - saas
  - frontend
  - backend
  - infrastructure
  - product
  - business
layout: post.njk
---

This post is a little later than I planned.

I meant to write it closer to the Spendseer launch, but every time I sat down to do that I ended up adding another feature instead. That is probably the most honest possible summary of what building a SaaS has felt like so far.

Spendseer started out much smaller than that. For years I tracked spending in Google Sheets, and while it worked, importing statement data into it was always annoying. I wrote some scripts to clean things up, then eventually turned that into a small app running on a Raspberry Pi in my homelab. Later it moved onto a proper server, and somewhere along the way it stopped being "my budget thing" and started looking like something other people could actually use.

That was the point where the work changed.

{% image "./src/assets/images/spendseer-dashboard.png", "Spendseer dashboard showing account balances, spending, and financial overview", "(min-width: 768px) 600px, 100vw" %}

## The App Wasn't the Hard Part

The core product already existed in some form because I had been using it myself. What I underestimated was everything around the product that suddenly matters once you want to charge for it:

- billing and subscriptions
- auth and account management
- email flows
- privacy policy and terms
- production infrastructure
- onboarding and UX polish

That was the real shift. Building a tool for yourself is one problem. Building something another person can sign up for, trust, and pay for is a different one.

AI helped a lot here too. I like using it to get projects moving faster and cut down on a lot of the tedious setup work. Pair that with a homelab and something like Cloudflare Tunnels, and it is easier than ever to get an idea online fast.

But fast is not the same as finished.

AI is great at getting you to working code. It is much less great at the steady cleanup that makes a product feel solid. A lot of the last stretch was just polishing rough edges, simplifying flows, and fixing the kind of annoyances you only notice after living in the app.

## Why This Post Was Late

A quick look through the git history over the past month makes it pretty obvious why this post slipped. Instead of writing about Spendseer, I kept improving it.

Some of the bigger changes were:

- A much better import review flow, including cleaner previews, better source handling, and improved duplicate detection.
- Bulk transaction actions and import revert support, which makes fixing mistakes a lot less painful.
- A more usable categorization rules UI, making important configuration much easier to manage.
- Major dashboard and yearly overview improvements, including better recurring payment handling, sticky overview columns, and subcategory-aware filtering.
- I have also been looking at optional AI bill and receipt extraction, which I may add if it works well enough in practice.

There were also plenty of smaller fixes, test cleanups, and UX tweaks mixed in there, which is usually how these things go.

## What I Actually Wanted Out of This

Part of the reason I built Spendseer was that I wanted a budgeting tool that handled imports the way I wanted. Most tools either expect manual entry or depend on bank integrations that usually require handing over your login details because banks do not offer proper APIs. I wanted something that could take exports and statements from different places, give me a single pane of glass for my spending, and do it with a lot less effort than manual entry.

The other part was simpler: I wanted experience building the full SaaS package.

Not just the app. The pricing decisions. The billing flows. The support questions I had not thought about yet. The uncomfortable moment where you decide whether something you built is good enough to charge money for.

That last one was probably the biggest mental hurdle. Releasing a free tool feels very different from putting a price tag on it. It forces you to ask better questions about reliability, polish, and whether you would pay for it yourself.

I still do not think the goal was to build a perfect SaaS. The goal was to build one, launch it, and learn from the process. On that front, it has already been worth it.

Spendseer is live at [app.spendseer.com](https://app.spendseer.com).

If you want to try it, I am also offering $10/year off until April 30, 2026.

And if nothing else, I ended up with a finance tool I actually enjoy using, which was the original point anyway.
