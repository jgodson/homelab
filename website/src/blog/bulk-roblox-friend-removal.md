---
title: How I Bulk Removed Roblox Friends with Browser Developer Tools
description: A practical walkthrough of using browser developer tools and ChatGPT to script bulk Roblox friend removal.
date: 2025-12-29
tags:
  - automation
  - roblox
  - scripting
  - ai
layout: post.njk
---

## TLDR

If you want to easily remove lots of Roblox connections, you can copy and paste the full script in the [Appendix](#roblox-friend-removal-script) into the browser console on the connections page in Roblox. For full context, read on.

## The Problem

My son had accumulated over 200 Roblox friends, most of whom he didn't actually know. This wasn't really a problem until he paid for a private server on one of his favourite games. Private servers allow your Roblox friends to join - meaning the ones he wanted could join, but all those other ones as well - friends that often join and steal his Brainrots.

This was the point he came to me and asked how he could block those people from his server.

I fully acknowledge the irony here, given that the game is literally called *Steal a Brainrot*, and he’s playing on a private server specifically so his don't get stolen... but I digress.

### The Solution

Removing connections is not difficult - you go to the user's profile page and click a button. The real problem was that I would need to do that nearly 200 times. Roblox doesn’t offer any bulk selection mechanism or other way to manage this that I’m aware of.

There are some Chrome extensions that claim to do this, but their ratings were pretty low and the whole thing felt a little questionable. I decided to tackle it myself instead.

The plan was to write a script I could execute directly in the browser console. I’d used a similar approach before when exporting Wealthsimple credit card transactions (that write-up is [here](/blog/wealthsimple-csv-export)).

The first step was figuring out how Roblox actually removes a friend. I opened the developer tools in Safari, navigated to a user’s profile page, and clicked the "Remove Connection" button. Watching the Network tab revealed a request being sent to `https://friends.roblox.com/v1/users/_id_/unfriend`.

{% image "./src/assets/images/roblox-friend-removal-3.png", "Button location to remove a Roblox connection", "(min-width: 768px) 600px, 100vw" %}

With that in hand, I needed a list of user IDs to send requests to. Using **Inspect Element** from the right-click menu on the connections page, I was able to locate a consistent HTML structure containing each user’s ID.

```html
<div class="avatar-name-container">
    <a href="/users/_id_/profile" class="text-overflow avatar-name">Name</a>
</div>
```

{% image "./src/assets/images/roblox-friend-removal-1.png", "Inspect Element on Roblox connections page", "(min-width: 768px) 600px, 100vw" %}

{% image "./src/assets/images/roblox-friend-removal-2.png", "HTML elements that will work for getting the user id", "(min-width: 768px) 600px, 100vw" %}

At this point, I had everything I needed. Normally, this is where I’d write a script by hand and go through some trial-and-error testing to get it working. But it’s almost 2026, and AI is genuinely good at this kind of task.

So instead, I went to ChatGPT and prompted it with what I’d learned so far — including the list of friend IDs he actually wanted to keep.

{% image "./src/assets/images/roblox-friend-removal-5.png", "HTML elements that will work for getting the user id", "(min-width: 768px) 600px, 100vw" %}

The script ChatGPT generated was *nearly* perfect. It accounted for rate limits and attempted to retrieve the CSRF (Cross-Site Request Forgery) token from the page so that the requests would work properly. This token is embedded in the HTML and is used to ensure that incoming requests are legitimately made by the logged-in user.

However, when I tried to run the script, I kept getting an error saying the CSRF token couldn’t be found. After inspecting the page’s HTML and locating the relevant `meta` tag, the issue became obvious: the token was stored in a `data-token` attribute, not `content` as the script assumed.

The script originally had this:
```javascript
  // Grab CSRF token from page
  const csrfToken = document
    .querySelector('meta[name="csrf-token"]')
    ?.getAttribute("content");
```

It needed to be:
```javascript
  // Grab CSRF token from page
  const csrfToken = document
    .querySelector('meta[name="csrf-token"]')
    ?.getAttribute("data-token");
```

After that small tweak, the script was working perfectly!

At that point, the only real “issue” left was that Roblox only loads a limited number of friends per page. To get through the full list, I had to refresh the page before running the script again so it would pick up the next batch.

The good news is that this was easy to automate. After the `console.log("Done.")` I added a simple `window.location.reload()`. Now I could run the script, let the page refresh automatically, hit the up arrow to recall the last command, and press Enter in quick succession.

The list of user IDs at the top of the script acted as a safety net, making sure I didn’t accidentally remove any of his actual friends in the process.

{% image "./src/assets/images/roblox-friend-removal-4.png", "Pasting the script into the dev tools Console tab", "(min-width: 768px) 600px, 100vw" %}

## Reflections

This is the kind of problem where knowing how to read HTML and write JavaScript really pays off. There’s no question that AI tools like ChatGPT make this **much** faster and easier, but as we saw above, they’re not always perfect.

Being able to debug issues yourself - understanding **what to ask for**, **what context to provide**, and **how to spot and correct mistakes** is still a valuable skill. I think that will remain true even as AI tools continue to improve.

#### Appendix

##### Roblox friend removal script
```javascript
((async () => {
  // IDs to KEEP (do NOT unfriend)
  const keepIds = new Set([
    "1234"
  ]);

  // Grab CSRF token from page
  const csrfToken = document
    .querySelector('meta[name="csrf-token"]')
    ?.getAttribute("data-token");

  if (!csrfToken) {
    console.error("CSRF token not found. Are you logged in?");
    return;
  }

  // Find all user profile links on the page
  const links = Array.from(
    document.querySelectorAll('a[href^="/users/"][href$="/profile"]')
  );

  // Extract unique user IDs
  const userIds = [...new Set(
    links
      .map(a => a.getAttribute("href")?.match(/\/users\/(\d+)\/profile/)?.[1])
      .filter(Boolean)
  )];

  console.log(`Found ${userIds.length} users on page`);

  // Filter out users we want to keep
  const toUnfriend = userIds.filter(id => !keepIds.has(id));

  console.log(`Unfriending ${toUnfriend.length} users…`);
  console.log("Skipping:", [...keepIds]);

  // Helper delay
  const sleep = ms => new Promise(r => setTimeout(r, ms));

  for (const userId of toUnfriend) {
    try {
      const res = await fetch(
        `https://friends.roblox.com/v1/users/${userId}/unfriend`,
        {
          method: "POST",
          headers: {
            "X-CSRF-TOKEN": csrfToken,
            "Content-Type": "application/json",
          },
          credentials: "include",
        }
      );

      if (res.ok) {
        console.log(`✅ Unfriended ${userId}`);
      } else {
        console.warn(`❌ Failed ${userId}`, res.status);
      }
    } catch (err) {
      console.error(`Error unfriending ${userId}`, err);
    }

    // Delay to avoid rate limits
    await sleep(1200);
  }

  console.log("Done.");
  window.location.reload();
})();
```