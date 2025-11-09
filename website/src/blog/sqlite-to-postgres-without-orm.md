---
title: "Migrating from SQLite to PostgreSQL Without an ORM: A Humbling Experience"
date: 2025-11-09
description: "What I learned migrating two Rust apps from SQLite to PostgreSQL without an ORM and why ORMs save you from so much pain."
tags:
  - rust
  - postgresql
  - sqlite
  - database
  - orm
  - ai
layout: post.njk
---

## The Context

I've been building two Rust applications simultaneously. One, a Kubernetes cluster manager named `kube-manager` and the other an automation tool for my side projects I called `issue-to-pr` (naming is hard). I have been using AI as my primary coding partner. The approach was intentionally exploratory: give the LLM minimal direction, let it make most of architectural decisions, see what happens, then tweak later. 

Why this approach? Two reasons:

1. **I don't work with Rust much, but I love the language** - Strong type system, performance, good tooling. Side projects are the perfect place to explore languages you don't use daily.
2. **Side projects should be fun *and* educational** - Sure, these apps are useful for managing my homelab and GitHub workflow, but they're also learning opportunities. Let the AI drive, see what it builds, learn from the decisions it makes (good and bad).

I had mentioned when starting both apps that my plan was to use SQLite for local development and PostgreSQL for production.

## The Problem

After getting to a point where I felt ready to build Docker containers and deploy these apps to my homelab, I realized there were placeholder comments in the code like `// TODO: Add PostgreSQL support` and `// Currently using SQLite syntax`. I asked the AI what was needed to switch to PostgreSQL for production.

That's when I discovered that the LLM's choice of SQLx was going to be more complicated than I'd anticipated...

Coming from a world of ORMs in Ruby (ActiveRecord) and Node.js (Sequelize, Prisma), I'd never had to set up an application using raw SQL queries from scratch or think too much about changing the type of database used. There's the odd case where you may have raw SQL and I've worked on Go apps that use this pattern, but I'd never made the initial architectural decisions on those, or dealt with database migrations at this level.

I knew what ORMs do, but I'd never *felt* the pain they prevent before. This migration changed that.

## Why My LLMs Chose SQLx Over an ORM

Here's another interesting detail I learned: **Rust indeed has ORMs**. Diesel and SeaORM both support multi-database setups and would have made this migration trivial. Basically just change the connection string and it would have been done. So why did the AI tools (Claude) working on two completely different apps choose SQLx with raw SQL instead?

I thought this was especially curious considering I explicitly mentioned wanting to use "SQLite for development and PostgreSQL for production", a classic ORM use case. Yet both LLMs went with SQLx. Possible reasons that Claude gave me for this were:

1. **Recent training data bias** - SQLx + Axum is heavily featured in modern Rust web tutorials
2. **Async-first appeal** - SQLx is fully async, while Diesel's async support (diesel-async) is newer
3. **"Compile-time verification" marketing** - SQLx's compile-time checked queries is promoted as the "Rust way"
4. **Missing the implication** - The LLMs didn't connect "dual database support" with "this is what ORMs are for"

**With Diesel, the migration would have been:**
```rust
// 1. Change Cargo.toml feature flag
- diesel = { version = "2.1", features = ["sqlite"] }
+ diesel = { version = "2.1", features = ["postgres"] }

// 2. Update DATABASE_URL in .env
- DATABASE_URL=sqlite:./app.db
+ DATABASE_URL=postgresql://user:pass@localhost/db

// 3. Run migrations
diesel migration run

// Done. No code changes needed.
```

No placeholder replacements. No type migrations. No schema syntax conversions. The ORM handles it all.

This is a great example of why you shouldn't blindly trust AI architectural decisions. I told the AI what I needed, it chose a solution that sounded good, and I went with it without questioning whether there was a better approach. An ORM would have saved me from this entire migration headache. I suppose if that had happened though, I wouldn't have *experienced* what ORMs prevent and this blog post wouldn't exist 😂.

**The lesson:** When AI suggests a technology choice, ask yourself (or do some research on the topic if you don't know) and the AI: "Is there a more fitting tool designed specifically for this use case?". Sometimes the answer is yes, and the AI just didn't make that connection. Plus it's a good oppourtunity to learn about the topic yourself.

Now onto the hard part.

## The Migration

Both apps were using SQLite for development and I already have PostgreSQL 16 running in my homelab for other services (Gitea), which is why I planned to use that for my apps as well. However to continue along that path had some problems:

- **Duplicate queries**: Every database operation would have to have SQLite-specific (`?` placeholders) and PostgreSQL-specific (`$1, $2` placeholders) versions
- **Schema differences**: `INTEGER AUTOINCREMENT` vs `BIGSERIAL`, different timestamp handling
- **Type juggling**: SQLite's flexible typing vs PostgreSQL's strict types
- **Testing gaps**: Code paths that worked in SQLite might fail in PostgreSQL

Of course the LLM was happy to continue implmenting this. To me though this was a huge red flag, and the solution seemed straightforward: migrate to using PostgreSQL for both development and production to avoid huge amounts of duplicate code.

I could have changed to an ORM at this point, but stuck with SQLx as it felt like a smaller change this far in. I had a lot of app code written by this point.

### Local PostgreSQL Setup

First, I needed PostgreSQL running locally. I have a Mac and was going to use Docker Desktop, but didn't want to create an account just to use it. Instead, I went with Podman, which works essentially the same way, but without the account requirement.

I also decided to give each app its own database rather than sharing one. This way I can work on either app independently without needing a shared database setup. Each app got its own `docker-compose.yml` with PostgreSQL, though I had to make sure they were configured on different ports.

### The Expected Challenges

On the app side of things, I expected to need to do the following:

1. Convert schema syntax (not too bad)
2. Update SQL placeholders from `?` to `$1, $2, $3` (tedious but straightforward)
3. Change `INSERT OR REPLACE` to `INSERT ... ON CONFLICT DO UPDATE` (standard PostgreSQL)
4. Migrate existing development data from SQLite to PostgreSQL

Using AI to fast-track these changes was a huge time saver. It did still take quite a bit of iteration and Claude ended up creating several bash and python scripts to try and speed things up vs manual edits.

### The Surprise: DateTime Type Mapping

Assuming the changes were complete, we ran `cargo build` to test it out.

Then the compilation errors exploded:

```bash
error: mismatched types
  --> src/models.rs:12:5
   |
12 |     pub created_at: DateTime<Utc>,
   |     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = note: expected struct `time::OffsetDateTime`
              found struct `chrono::DateTime<Utc>`
```

We were using `chrono::DateTime<Utc>` for all the timestamp fields. It worked fine with SQLite. Why is PostgreSQL expecting `time::OffsetDateTime`?

Here's what I learned: **SQLx's type mapping behavior differs between databases.**

#### With SQLite
- SQLite stores timestamps as `INTEGER` (Unix timestamp) or `TEXT` (ISO 8601)
- SQLx has adapters that convert these to/from `chrono::DateTime<Utc>`
- Everything worked seamlessly

#### With PostgreSQL + SQLx
- **SQLx maps `time::OffsetDateTime` as the default for PostgreSQL `TIMESTAMP` types AND `TEXT` columns**
- This is a deliberate choice—the `time` crate is considered more robust and actively maintained
- **While SQLx still supports `chrono` with the appropriate feature flags, `time::OffsetDateTime` is the preferred type**

On that last point: SQLx *does* support `chrono::DateTime` for PostgreSQL if you enable the `chrono` feature. I could have kept using `chrono::DateTime<Utc>` everywhere and avoided most of this migration pain. *However* the LLM (Claude, Sonnnet 4.5 to be specific) never suggested this as an option.

Why? This highlights a key limitation of LLMs: **they optimize for "the recommended path" based on their training data, not necessarily "the path of least friction for your specific situation."** The SQLx documentation and tutorials emphasize `time` as the preferred choice, so that's what the AI gravitates toward. It doesn't consider the pragmatic trade-off: "Yes, `time` is better, but you have 60+ timestamp fields already using `chrono`. Maybe just enable the feature flag?"

This is a pattern I've noticed: LLMs are great at following best practices but sometimes miss the obvious shortcut that would save hours of work. They don't naturally think "what's the minimal change to make this work?" unless you explicitly frame the problem that way.

**The catch-22:** LLMs lack the ability to add nuance to their suggestions unless you explicitly guide them toward it. But to provide that explicit guidance, you often need to already understand the problem space well enough to know what nuance is missing. If I had known that SQLx supported both `chrono` and `time`, I could have asked "why don't we keep using chrono?" I didn't know that was even an option as the LLM never offered it, so I never thought to ask. This is where AI-assisted development can create a false sense of expertise, the AI confidently leads you down one path, and you follow along assuming it has considered all the alternatives.

### Surprise V2: Uuid vs String

After fixing all the DateTime issues, I got new compilation errors, all in my Askama templates:

*(Example from kube-manager)*
{% raw %}
```bash
error: comparison between Uuid and &str is not allowed
  --> templates/clusters/list.html:45:23
   |
45 |                 {% if cluster.id == cluster_id %}
   |                       ^^^^^^^^^^^^^^^^^^^^^^^^^
```
{% endraw %}

I was now comparing `Uuid` fields with `String` template variables. The fix required making `ClusterInfo.id` a `String` instead of `Uuid`, with `.to_string()` conversions at every creation site.

I do really like that **Askama compiles templates with full type checking**. It's not just string interpolation, it's checking types at compile time, which is amazing for catching bugs, but surprising if you're used to dynamic template engines. Both apps use Askama, so both had these template type issues to fix during the migration.

### Two Apps, Two Approaches

Another interesting aspect I wanted to note, my two AI sessions ended up migrating the two apps differently:

**Issue-to-PR-app** (8.6k lines, 23 templates):
- Kept `TEXT` columns storing RFC3339 strings
- Only changed Rust code: `chrono::DateTime<Utc>` → `time::OffsetDateTime`
- **Much faster** - completed fairly quickly
- Still works, but learned that it misses PostgreSQL's native timestamp features

**Kube-manager** (15.5k lines, 67 templates):
- Full PostgreSQL native types
- Changed schema: `TEXT` → `TIMESTAMP WITH TIME ZONE`
- Rust code: `chrono::DateTime<Utc>` → `time::OffsetDateTime`
- Gets all the benefits of PostgreSQL's native timezone handling, indexing optimizations, and temporal functions
- **Significantly longer** - took many more iterations

Both approaches required changing all the Rust code to use `time::OffsetDateTime`, but kube-manager's approach is more "correct" for PostgreSQL.

Why the different approaches? Here's the fascinating part: **I didn't explicitly choose either approach**. The LLM made these decisions again autonomously during two separate migration sessions. I don't know what factors led it to choose `TEXT` for one and `TIMESTAMP` for the other. Was it something in how I phrased my request? The order I mentioned files? The time of day affecting the model's context window? The random seed of the inference?

This, again, is one of the most interesting, and sometimes unsettling, aspects of working with LLMs: they make consequential technical decisions based on factors you can't fully observe or control. The `TEXT` migration was faster, the `TIMESTAMP` migration was more "correct", and I got both approaches without explicitly requesting either one.

What I *can* say is that after the `TEXT` approach on my issue-to-pr-app, I didn't expect kube-manager to take so long and I didn't really question _why_ it was taking so much longer as I didn't look closely enough to notice the difference in approach. The irony? The larger codebase got the "proper" approach that took significantly longer.

And here's where the learning kicks in: now that I understand the difference between `TEXT` and native `TIMESTAMP` types (`TEXT` being more of a "quick and dirty" approach), I'll probably go back and migrate issue-to-pr-app to use proper `TIMESTAMP WITH TIME ZONE` columns. I suspect doing it on the smaller codebase should be much quicker, especially with the other issues already fixed. Sometimes "just work" can be the right call to make progress, but once you understand *why* the proper way matters, it's worth going back and doing it right.

## A Dive Into The Code

The main difference between the two migrations was the database schema approach, but both had to deal with the same DateTime and template type issues.

### Kube-manager: Full PostgreSQL Migration
```rust
// OLD schema (SQLite)
CREATE TABLE clusters (
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

// NEW schema (PostgreSQL)
CREATE TABLE clusters (
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

// Rust code changes (same for both apps)
use time::OffsetDateTime;

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct Cluster {
    pub id: Uuid,
    pub name: String,
    pub created_at: OffsetDateTime,  // Changed from chrono::DateTime<Utc>
}

let now = OffsetDateTime::now_utc();  // Changed from Utc::now()
```

### Issue-to-PR-app: Minimal Migration
```rust
// Schema stayed the same - still TEXT
CREATE TABLE repositories (
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

// But Rust code changed identically
use time::OffsetDateTime;

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct Repository {
    pub id: i64,
    pub name: String,
    pub created_at: OffsetDateTime,  // Changed from chrono::DateTime<Utc>
}

// SQLx automatically converts RFC3339 strings ↔ OffsetDateTime
let now = OffsetDateTime::now_utc();  // Changed from Utc::now()
```

### The Key Difference

**Kube-manager** gets PostgreSQL's native timestamp features:
- Timezone-aware operations
- Efficient indexing on timestamp ranges
- Native date/time functions (`NOW()`, `AGE()`, etc.)
- Automatic timezone conversions

**Issue-to-PR-app** keeps it simple:
- No schema migration needed
- Data stays as RFC3339 strings
- SQLx handles the conversion transparently
- Good enough for most use cases

Both compile and run correctly with `time::OffsetDateTime` in Rust. The difference is whether you want PostgreSQL's native timestamp power or just want to migrate with minimal changes.

## The AI Advantage

I do want to give credit where it's due: **I used AI (Claude with GitHub Copilot) heavily to develop these apps and to do the migration and it would have taken 10x longer without it.**

For the migration specifically, the AI was able to whip up scripts to do:

1. **Bulk placeholder replacements**: Converting 200+ `?` to `$1, $2, $3...` across 15+ files
2. **Pattern recognition**: Identifying all the places where `Utc::now()` needed to become `OffsetDateTime::now_utc()`
3. **Type migration**: Updating all the model structs consistently
4. **Template fixes**: Adding `.to_string()` conversions in 60+ locations

Had this been an existing app, this could have been hours of manual, error-prone work. The AI did make mistakes (ie: some of the scripts did the wrong thing and we had to checkout the previous version from `git` and try again), but having a "pair programmer" to bounce ideas off and handle tedious replacements is invaluable.

## Lessons Learned

### 1. ORMs Hide a TON of Complexity
When you use an ORM, switching databases often means just changing a connection string. The ORM handles all the messy details. With raw SQL and SQLx, I had to deal with all of that manually and experiencing it firsthand really drove home how much tedious work ORMs save you from.

### 2. Template Type Checking Is Powerful
Askama's compile-time template checking is stricter than Ruby's ERB or JavaScript's template engines. It caught many bugs before they could happen.

### 3. Type Systems Are Still Your Friend (But Not Perfect)
Now that said, Rust's compile-time checking caught the vast majority of incompatibilities, type mismatches, template errors, all before a single line of code ran. I did _still_ encounter a few runtime errors after starting the app. For example, SQLite was lenient about nullable columns (treating missing values as `NULL`), but PostgreSQL enforced `NOT NULL` constraints strictly, causing queries to fail when trying to insert records without certain fields. There was also a `LIMIT` validation error where a negative value passed in somehow worked in SQLite but PostgreSQL rejected it. The strict type system minimized runtime issues dramatically, but it's still important to actually run and test your app's functionality.

### 4. Do Some Reading Before Relying on LLMs
Even 15-20 minutes of research about "Rust database libraries" or "SQLx PostgreSQL migration" would have given me enough baseline knowledge to have informed input into the LLM's decisions. You don't need to become an expert, but understanding the landscape means you can ask better questions and spot when the AI might be missing something obvious. SQLx has guides for PostgreSQL that document the `time` vs `chrono` distinction, I just didn't know to look for it until looking into it for this post.

### 5. Test with "Production" Database Early
If I'd started trying to use PostgreSQL right away, I would've encountered this immediately. Instead I happily continued development with SQLite until the app had a lot of functionality. The SQLite → PostgreSQL transition added complexity late into things that I didn't anticipate.

### 6. AI Is Great At The Basics
For small changes, documentation, well scoped problems, bulk refactoring, pattern-based replacements, and consistency checks, AI tools are game-changers. For important things you still should understand what you're doing and check its work, or else you can end up in a rabbit hole like this one. Now of course, for prototypes and learning like I did here, it's still a win-win!

### 7. Commit Early, Commit Often
When using AI to make changes, commit your work frequently in small chunks. The AI will make mistakes. Scripts that do the wrong thing, overzealous replacements, broken logic. Being able to quickly `git checkout` the previous version and try again is essential. This applies to any development work, but it's especially critical when AI is making bulk changes you might not fully verify until after the fact.

## Conclusion

This was one of those humbling moments where something "basic" caught me off guard. I've built dozens of web apps with databases, but I'd never had to deal with database specific issues because ORMs abstracted it away.

**And that's okay.** Every tool has its abstractions, and every abstraction has its leaks. The key is stay curious, ask questions, read documentation, and don't be afraid to admit when you're learning something new, even if it feels like you should've known it already.

This experience also highlights two huge benefits of side projects:

1. **Exposure to new tools and approaches** - In my day-to-day work, I might never have ventured into raw SQL with Rust or dealt with database migrations at this level. Side projects let you explore technologies and patterns you wouldn't normally encounter, expanding your understanding of how things actually work beneath the abstractions. There's a good chance what you learn will be directly transferable to "real work" at some point.

2. **AI as a learning accelerator** - Using AI tools to build side projects faster means you hit these learning moments sooner and more frequently. Instead of spending weeks building boilerplate, you can use AI to fast-track to the interesting problems and gotchas. Building the app and completing this migration would've taken me days or weeks manually, meaning I learned these lessons quickly and can apply them to future projects.

## Wait, What About The Apps?

Glad you're interested! I'll probably add these to the homelab repo, or make the repos public at some point. Most likely accompanied by a blog post about each, but here's a quick preview of what I've managed to create in the past week.

### Issue to PR

{% image "./src/assets/images/issue-to-pr-preview.png", "Issue to PR App Homepage", "(min-width: 768px) 600px, 100vw" %}

### Kube Manager

{% image "./src/assets/images/kube-manager-preview.png", "Kube Manager Homepage", "(min-width: 768px) 600px, 100vw" %}
