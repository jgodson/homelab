---
title: Wealthsimple Won’t Let You Export Your Credit Card Transactions? Here's How I Did It Anyway
description: Wealthsimple’s new credit card is great, but there’s no CSV export yet. Here’s how I built a custom browser script to export my transactions and integrate them into my app.
date: 2025-04-27
tags: 
  - blog
  - automation
  - finance
  - scripting
layout: post.njk
---

When Wealthsimple launched their new credit card, I was excited. Simple rewards, clean design, good app experience. But when I went to pull my credit card transactions to import into my personal finance tracker, I realized something was missing: **There's no CSV export option.**

At least, not yet. So I built my own.

This post covers how I built a quick browser script to export all my Wealthsimple Credit Card transactions, the weird problems I ran into, and how I integrated the data into my app.

## Getting the Raw HTML

The first step was figuring out how the transaction list was actually structured.

- I logged into my Wealthsimple account.
- Opened the Credit Card section.
- Right-clicked on the transactions page and selected **Inspect Element** to open the Developer Tools. Yes, I use Safari on my personal laptop. If you don't see that option, you'll have to turn on Developer tools — or use Chrome, Firefox, etc 😄.
- Inspected the HTML to see what was going on.

I found that Wealthsimple uses random class names (like `.sc-e8c84276-1`), meaning I couldn’t rely on CSS selectors. Instead, I needed to target the HTML structure (e.g., `<h2>` for dates, `<button>` for transactions).

Scraping HTML like this is always prone to breakage, but it will work for now!

## Writing the Extraction Script

I wrote a quick JavaScript script that:
- Walks through the DOM.
- Picks up the **date**, **description**, and **amount** for each transaction.
- Downloads everything as a `.csv` file.

At first the results were messy:
- Duplicate transactions.
- Refunds and purchases were not distinguished.
- Fields with commas (like `April 23, 2025`) broke the CSV parser.

After a few iterations, I ended up with a cleaner, more robust script. Quoting fields correctly in CSVs is crucial when your data contains commas. See the [Appendix](#wealthsimple-credit-card-transaction-download-script) for the full script.

## Hidden Problems: Unicode Minus Signs

One issue was sneaky: Wealthsimple’s UI uses a **Unicode minus character** (U+2212) instead of the normal ASCII `-`.

This meant when I parsed the amounts in Ruby using `.to_f`, negative numbers were silently treated as positive!

**Example:**
- `"−73.97"` (Unicode minus) → incorrectly parsed as `73.97`

The fix was easy enough once I realized the issue — normalize the minus sign in Ruby before parsing:

```ruby
def parse_amount(amount_str)
  cleaned = amount_str.tr("−", "-").gsub(/[^\d\.\-]/, '')
  amount = cleaned.to_f
  (-amount * 100).round
end
```

## Integrating With My App

I already had an importer service that handles credit card transactions in `.csv` files from other banks. Adding Wealthsimple support was just a matter of creating a new importer class that:

- Cleans the date and amount fields properly.
- Inverts the transaction value as my app uses negative for refunds.
- Import everything as transactions into the database.

My app code isn’t public yet, but it’s built around a flexible import system — making it easy to add new sources like this.

## Reflections

The biggest surprise here wasn’t the technical challenges — it was realizing how basic features to export data are missing from major apps in 2025.

Wealthsimple’s Credit Card experience is polished in a lot of ways, but not giving users easy access to their own transaction data feels like a gap. When that happens, as developers, we don't have to wait for permission — we can build the tools we need.

With just a little code and some digging into the page structure, I was able to create a fully working exporter — turning a missing feature into a solved problem in less than half an hour. It could have taken longer, but when you can get ChatGPT to write most of the script, it speeds things up 😄.

This is what I love about being a developer and the power of code:

See a gap
Build a bridge
Keep moving

Tools like this don't just save time — they create freedom as you don't have to rely on someone else deciding what's important for you.

---

Thanks for reading! Stay tuned for more post about things in my life related technology, my homelab, home improvement, etc!

#### Appendix

##### Wealthsimple Credit Card transaction download script
```javascript
(function() {
  const rows = [];

  const buttons = document.querySelectorAll("button");

  buttons.forEach(button => {
    let date = null;
    let el = button;
    while (el && !date) {
      el = el.previousElementSibling || el.parentElement;
      if (el && el.tagName === "H2" && /\d{4}|Today|Yesterday/i.test(el.textContent)) {
        date = el.textContent.trim();
      }
    }

    const ps = button.querySelectorAll("p");
    const description = ps[0]?.textContent.trim();

    let amount = null;
    ps.forEach(p => {
      if (/\$\d/.test(p.textContent)) {
        amount = p.textContent.trim();
      }
    });

    if (date && description && amount) {
      rows.push([date, description, amount]);
    }
  });

  const uniqueRows = Array.from(new Set(rows.map(e => e.join("|")))).map(r => r.split("|"));

  function csvEscape(value) {
    if (typeof value !== 'string') return value;
    if (value.includes(',') || value.includes('"') || value.includes('\n')) {
      return `"${value.replace(/"/g, '""')}"`; // Escape double quotes by doubling them
    }
    return value;
  }

  const csvHeader = ["Date", "Description", "Amount"];
  const csvRows = [csvHeader, ...uniqueRows];

  const csvContent = "data:text/csv;charset=utf-8,"
    + csvRows.map(row => row.map(csvEscape).join(",")).join("\n");

  const encodedUri = encodeURI(csvContent);
  const link = document.createElement("a");
  link.setAttribute("href", encodedUri);
  link.setAttribute("download", "transactions.csv");
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
})();
```