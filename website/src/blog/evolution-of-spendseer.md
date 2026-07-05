---
title: "The Evolution of SpendSeer"
description: How SpendSeer changed after launch, from the original yearly overview to better imports, recurring payment detection, loan reviews, goal context, and operational polish.
date: 2026-07-05
tags:
  - saas
  - product
  - spendseer
  - rails
layout: post.njk
spendseerTourYoutubeId: "ts9x8yIC0r4"
---

When I wrote about launching SpendSeer in April, one line was more true than I probably realized at the time: the post was late because I kept adding features.

This post is basically the longer version of that.

I went back through the commits for this because it is easy to remember the current app and accidentally project it backwards. SpendSeer did not launch with the dashboard overview, recurring payment detection, import health checks, or loan payment review flow it has now. It launched with a much simpler shape, and then I kept pushing the rough parts forward.

{% if spendseerTourYoutubeId %}
    {% youtubeEmbed spendseerTourYoutubeId, "SpendSeer product tour: from budget data to financial confidence", "A quick caption-led tour of the post-launch workflows: imports, rulesets, activity health, loan review, goals, budgets, and the dashboard." %}
{% endif %}

## Launch Baseline: The Yearly View

At launch, SpendSeer already had the SaaS wrapper around it: accounts, workspaces, billing, a public demo, imports, budgets, categories, rules, loans, goals, and the infrastucture it needed.

But the main screen was not the dashboard hub it has now. The dashboard route was the yearly overview: one big annual view with charts, category rows, budget amounts, monthly actuals, and totals.

{% image "./src/assets/images/spendseer-evolution-launch-yearly-overview.png", "SpendSeer launch-era yearly overview with annual charts and category rows", "(min-width: 768px) 600px, 100vw" %}

That mattered because this was already enough to solve my original problem. I could import transactions, compare them against a budget, and see the year in one place.

It also made the missing pieces pretty obvious. The app could show me the data, but it still expected me to do a lot of interpretation myself. Recurring payment detection was not there yet. The dashboard was not a starting point. Imports needed more review and recovery tools. Loan payments and goal contributions existed as concepts, but they were not connected into the import flow the way they needed to be.

That is where most of the post-launch work went.

## March: Turning a View Into a Dashboard

The first big visual change was splitting the old all-in-one dashboard into a real dashboard entry point plus separate yearly and monthly views.

That sounds like a small navigation change, but it changed the product. The yearly overview stayed important, but it stopped being the only place to start. The dashboard became a summary surface: jump into the yearly view, jump into the monthly view, see active goals and loans, and eventually see upcoming payments.

{% image "./src/assets/images/spendseer-evolution-dashboard-overview.png", "SpendSeer dashboard overview added after launch with yearly, monthly, at-a-glance, and upcoming payment sections", "(min-width: 768px) 600px, 100vw" %}

Recurring payment detection belongs in this part of the timeline too. It was not a launch feature. It started as a way to stop mentally tracking the same bills every month, then became a dashboard surface that could show what was likely coming next.

The hard part was not just finding repeated merchants. It was making the guesses useful without making the dashboard noisy. That led to source-aware detection, handling extra payments, hiding low-confidence subsets, and later tuning variable recurring payments so the feature felt helpful instead of nagging.

## Late March and April: Imports Got More Serious

The next theme was imports. SpendSeer could already import transaction data, but post-launch work made that workflow feel much less risky.

This included a better draft review flow, async import commits, clearer duplicate candidates, stable import source identities, import batch revert, and better rules screens. The reason was practical: import is where the app either saves time or creates cleanup work. If I cannot trust that screen, the rest of the app does not matter much.

The AI bill and receipt extraction work also landed in this period. I [wrote about the two-pass pipeline separately](/blog/two-pass-ai-pipeline/), but the important product decision was that AI did not get to write directly into the ledger. It creates draft rows, and those rows still go through review. That work is still behind a feature flag and is not generally available in SpendSeer.

{% slideshow %}
    src/assets/images/spendseer-ai-extraction-demo-1.png, Starting an AI extraction from the transaction import form
    src/assets/images/spendseer-ai-extraction-demo-2.png, Import batch processing while the worker extracts rows
    src/assets/images/spendseer-ai-extraction-demo-3.png, Completed draft import ready for review before committing
    src/assets/images/spendseer-ai-extraction-demo-bill.png, Example bill document used as extraction input
{% endslideshow %}

The less flashy import work probably mattered more day to day. Import sources started carrying more meaning. Rulesets became easier to manage. Activity health could flag a source that usually shows up monthly but has gone quiet. Category icons made import and rules screens easier to scan.

{% slideshow %}
    src/assets/images/spendseer-evolution-source-defaults.png, Saved import source labels with a default ruleset assigned to a specific account
    src/assets/images/spendseer-evolution-rulesets.png, A source-specific ruleset that categorizes matching merchants during import
    src/assets/images/spendseer-evolution-activity-health.png, Activity health catching a source that usually appears monthly but has a missing statement
    src/assets/images/spendseer-evolution-category-icons.png, Category icons making income, expense, savings, and loan categories easier to scan
{% endslideshow %}

Icons sound cosmetic, but they helped more than I expected. Categories show up everywhere: imports, rules, budgets, goals, loans, and dashboards. Giving them a small visual identity made the whole app easier to scan.

By the end of this phase, imports were not just "upload a file and hope." They were becoming a workflow: source, preview, rules, draft review, commit, and recovery if something went wrong.

## May: Loans, Goals, and Categories Had to Agree

May was where the connected parts of the app started to matter more.

Loan payments are a good example. A car payment is money leaving the account, so it belongs in spending. But it is also a balance change, and only part of the payment reduces principal. If SpendSeer treats the whole thing like a normal expense, the budget can look fine while the loan balance quietly drifts.

The May work added imported loan payment detection, review states, expected payment gap checks, and balance recalculation from payment history. At that point, the loans page stopped being only a place to type balances and became more of an audit surface.

{% slideshow %}
    src/assets/images/spendseer-evolution-loan-balances.png, Loan balances recalculated from payment history instead of only manual balance edits
    src/assets/images/spendseer-evolution-loan-payment-review.png, Imported loan payment detection with paid amount, interest estimate, balance after, and confirm/reject actions
{% endslideshow %}

Goals had a similar problem. They already existed, but the app needed to be clearer about when a category was doing extra work. By late May, selecting a category could imply that a transaction contributes to a goal, affects a loan, or needs special treatment during import review.

So I added audits, import badges, and dynamic category context on forms. The point was not to make categories more complicated. It was to stop hiding the consequences of a category choice.

{% slideshow %}
    src/assets/images/spendseer-evolution-import-review-draft.png, Draft import review showing duplicates, a new category, a detected loan payment, and a goal contribution before anything is committed
    src/assets/images/spendseer-evolution-goals-progress.png, Goals showing category-backed progress, contribution totals, and remaining amounts
    src/assets/images/spendseer-evolution-goal-context-form.png, Transaction form context explaining that a savings-category transaction will count toward a goal
{% endslideshow %}

This is the kind of work that makes the app feel less like separate pages and more like one model. A transaction is not just a row in a table. It can affect a budget, a goal, a loan balance, an upcoming payment, and an audit trail.

## June: Less Flashy, More Durable

June was less about big new surfaces and more about making existing screens easier to live in.

The budgets table is a good example. A yearly budget has a lot of horizontal and vertical data. If the month headers disappear while scrolling, the table becomes annoying fast. Sticky headers are not exciting, but they make the page easier to use every time.

{% slideshow %}
    src/assets/images/spendseer-evolution-budgets-sticky-table.png, Budget month headers staying visible while reviewing category rows
    src/assets/images/spendseer-evolution-bulk-date-edit.png, Bulk transaction editing with an explicit change-date modal and selected-row count
{% endslideshow %}

Some of the June work was even less visual: fixing bulk transaction date edits, stabilizing analytics comparison dates, and tolerating runtime cache outages. That last one is boring in the best way. A cache problem should not take down the core app.

This is the part of SaaS work that does not make a great feature announcement, but matters in production. Bulk edits should do exactly what they say. Analytics should not drift because the date math is fragile. One broken supporting service should not turn into a broken product.

## What Changed

Looking back, the evolution of SpendSeer has mostly been about moving judgment into the app without removing review.

At launch, SpendSeer could hold the basic financial model. It could show the year, import transactions, track budgets, and organize categories, loans, and goals.

After launch, the work became more about trust:

- Can imported data be reviewed before it becomes real?
- Can a repeated bill be detected instead of remembered manually?
- Can loan balances be recalculated from actual payments?
- Can category choices show their downstream impact before saving?
- Can the UI keep context visible while the data gets bigger?
- Can the app keep working when a supporting service has a bad day?

That is the real product work now. SpendSeer is still a budgeting app, but the valuable parts are increasingly the workflows around the budget: import review, recurring payment detection, loan and goal audits, category context, and enough operational resilience that I can trust it day to day.

The launch version was real enough to use. The work since then has been about making it easier to trust.
