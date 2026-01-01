---
title: Creating a Personal Budget App and Converting it to Open Source
description: How I built an automated Github sync script to open source my personal budget app while protecting sensitive data
date: 2025-07-29
tags:
  - rails
  - open-source
  - finance
  - automation
  - backend
layout: post.njk
---

## The Context

For several years I had been using Google Sheets to track spending and set up a budget, however I found myself very frustrated when I had to manually enter all of my transactions into it. I eventually wrote some Ruby scripts to reformat statement data from multiple credit cards so I could copy and paste it into Google Sheets — however, it was still a pain as it would cause issues with formatting and I'd have to spend time fixing it. Finally one day I decided it was time to make it all a bit more automated and have a UX I had more control over, so I built my own app.

I chose Ruby on Rails to build it with for two reasons. First, I wanted something easy to work with and I was familiar with. The second, I wanted to more deeply learn Rails by building an app from scratch as I generally spend most of my time working on existing apps.

## The Challenge with Open Source

Fast forward to now, the app is working well for me - it imports transactions from various banks, categorizes expenses using regex patterns, and helps me manage budgets and financial goals with far less manual processes than before.

Thinking about putting the code out publicly as is though, the transaction categorization patterns contained personal information. Patterns like `/local_business/i => 'Kid Stuff'` and `/jasons_favorite_restaurant/i => 'Entertainment'` revealed not just my location, but family details and personal habits. This is certainly the kind of data you don't want in a public repository.

I wanted to open source the application. The Rails architecture, import services, and financial management features could be interesting to other folks, or help them build their own budget tracking tools, but how could I share the code while protecting my privacy and not involve a ton of manual work?

## The Solution: Automated Sanitization

The answer was building an automated sync system that maintains two repositories:

1. **Private repo**: Contains my real transaction patterns and automation scripts
2. **Public repo**: Contains sanitized example patterns suitable for public consumption

### Key Components

#### 1. Privacy Assessment
First, I audited exactly what personal data was embedded in the code:

```ruby
# PRIVATE: Real personal patterns (kept private)
CATEGORY_PATTERNS = {
  /local_childrens_center/i => 'Kid Stuff',
  /jasons_favorite_spot/i => 'Entertainment',
  /local_grocery_store/i => 'Food'
}

# PUBLIC: Generic examples (safe to share)
CATEGORY_PATTERNS = {
  /daycare/i => 'Kid Stuff',
  /restaurant/i => 'Entertainment',  
  /grocery/i => 'Food'
}
```

The private patterns revealed my city, family structure, and specific businesses I frequent. The public examples provide the same functionality without personal exposure.

#### 2. File Exclusion
I created a sync configuration that excludes sensitive files:

```bash
# Files to exclude from public repo
EXCLUDE_FILES=(
    "lib/shared/transaction_category_patterns.rb"
    "lib/shared/transaction_skip_patterns.rb"
)
```

#### 3. Automated File Processing
The sync script automatically:
- Copies all git-tracked files from private to public repo
- Excludes sensitive files using the configuration
- Renames `*_example.rb` files to their active counterparts to ensure the app can run without much initial effort
- Creates a public-specific `.gitignore`
- Commits and pushes changes automatically

```bash
# Smart sync using git ls-files (respects .gitignore)
git ls-files | while read -r file; do
    # Check exclusion rules and copy accordingly
    process_file "$file"
done
```

#### 4. Git Hook Automation
A `pre-push` hook ensures the public repo stays synchronized:

```bash
# Runs before every push to main branch
if [[ "$current_branch" == "main" ]]; then
    echo "🔄 Running automatic sync to public repo..."
    ./private/sync-to-public.sh
fi
```

### Technical Implementation

The sync system uses several key techniques:

- **Git-aware copying**: Uses `git ls-files` instead of `rsync` to respect `.gitignore` rules. This limits the number of exclusions I have to add to the sync configuration
- **Pattern-based exclusion**: Excludes files by name patterns while preserving directory structure  
- **File transformation**: Automatically renames example files to production names in public repo

## Results

The system works seamlessly:

1. I push changes to my private repo (with real transaction patterns)
2. Pre-push hook automatically triggers sync script  
3. Public repo updates with sanitized code and generic examples
4. Other developers can clone the repo and use the generic patterns as starting points

### Repository Structure

**Private Repo:**
```
├── lib/shared/
│   ├── transaction_category_patterns.rb      # Real personal patterns
│   ├── transaction_category_patterns_example.rb  # Generic examples
│   └── transaction_skip_patterns_example.rb
├── private/                                   # Automation scripts (git-ignored)
│   ├── sync-to-public.sh
│   ├── sync-config.sh
│   └── install-hooks.sh
└── .gitignore                                # Excludes private/ folder
```

**Public Repo:**
```
├── lib/shared/
│   ├── transaction_category_patterns.rb      # Copied from *_example.rb
│   ├── transaction_category_patterns_example.rb
│   └── transaction_skip_patterns_example.rb
├── LICENSE                                   # CC BY-NC 4.0
├── PRIVACY.md                                # Privacy guidelines
└── PUBLIC_REPO_NOTE.md                       # Notice about sanitization
```

## Privacy Protections

### Licensing
I chose Creative Commons Attribution-NonCommercial 4.0 (CC BY-NC 4.0) to:
- Allow personal and educational use
- Prevent commercial use
- Require attribution while protecting my interests

### Documentation
Added clear privacy guidelines for contributors:
- How to customize transaction patterns safely
- What personal data to avoid in pull requests  
- Guidelines for creating generic examples

## Lessons Learned

### 1. Privacy by Design
Consider privacy implications before the first commit. Personal finance apps can be particularly sensitive - you can reveal lifestyle, location, family structure, and spending habits.

### 2. Automation Prevents Errors  
Manual sanitization is error-prone. Automated systems ensure consistency and prevent accidental data exposure.

### 3. Git Hooks Enable Seamless Workflow
The pre-push hook makes the dual-repo system invisible. I work normally on my private repo, and the public repo stays automatically synchronized.

### 4. Generic Examples Have Value
The sanitized examples aren't just privacy protection - they're documentation. They show other developers how the system works without exposing personal details.

## Open Source Impact

The public repository at [github.com/jgodson/budget-app-public](https://github.com/jgodson/budget-app-public) now provides:

- **Rails 7 app architecture**
- **Multi-bank import services** for some Canadian financial institutions
- **Generic transaction categorization** that users can customize
- **Goal tracking and loan management** features
- **Docker deployment** configuration

Other developers can fork the repository, customize the transaction patterns for their region/needs, and build their own budget management tool, or just use what they want/learn from it. That's the beauty of open source.

## Conclusion

Converting a personal application to open source doesn't require sacrificing privacy. With careful planning, automated sanitization, and smart git practices, you can share valuable code while protecting sensitive personal data.

The key is building systems that handle the complexity automatically. A few hours of automation setup now prevents years of manual work and potential privacy mistakes.
