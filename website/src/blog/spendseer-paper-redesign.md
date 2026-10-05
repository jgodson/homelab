---
title: "Giving SpendSeer a Paper Makeover"
description: Why I swapped SpendSeer's serious navy-and-gold look for a paper notebook style with stickers, tape, and a little confetti, now that I'm building it for me.
date: 2026-10-05
tags:
  - spendseer
  - frontend
  - ai
  - product
cover: ./src/assets/images/spendseer-redesign-cover.jpg
coverAlt: SpendSeer's redesigned dashboard on graph paper, with washi-tape labels and a sticky note
layout: post.njk
spendseerTourYoutubeId: "h_sUu-BTulE"
---

Last week I wrote about [redesigning this site with AI](/blog/redesigning-the-site-with-ai/). Similar to that, I decided to redesign SpendSeer too, and make it a lot more fun.

{% if spendseerTourYoutubeId %}
    {% youtubeEmbed spendseerTourYoutubeId, "SpendSeer product tour: budgeting with a brighter perspective", "The new product tour, showing the redesign." %}
{% endif %}

## Why Change It?

When I first built SpendSeer, I wanted it to look professional and sophisticated. It's a finance app, and I thought that's what a finance app should look like: dark navy, gold accents, serif headings, nothing silly.

Then I decided I would just [keep it live and build it for me](https://wildcatprojects.com/projects/spendseer/) instead of reworking it to attract users. Once it was for me, I didn't need it to look like a bank. I wanted it to be more fun and interesting to open, and to look more like the notebooks and spreadsheets I used to budget with.

{% slideshow %}
    src/assets/images/spendseer-redesign-before-dashboard.png, Before: the original navy-and-gold dashboard
    src/assets/images/spendseer-redesign-after-dashboard.png, After: the same dashboard in the paper notebook style
    src/assets/images/spendseer-redesign-before-signin.png, Before: the original sign-in page
    src/assets/images/spendseer-redesign-after-signin.png, After: sign-in on lined paper with sticky notes
{% endslideshow %}

## Paper, Tape, and Stickers

The new look is a craft notebook. The background is cardstock, cards and charts sit on graph paper, and the sign-in page and empty states use lined paper. Section labels are strips of washi tape, notes are sticky notes, and the sidebar has a torn paper edge. The page you're on gets a highlighter swipe.

I made the artwork with AI image generation: the logo, page illustrations, and a sticker for every category to replace the generic icons. That last one made a bigger difference than I expected. Categories show up on nearly every page, so giving them all little stickers changed the feel of the whole app.

{% slideshow %}
    src/assets/images/spendseer-redesign-dashboard-dark.png, Dark mode keeps the same notebook feel
    src/assets/images/spendseer-redesign-categories.png, Every category gets its own sticker
    src/assets/images/spendseer-redesign-empty-state.png, Empty states got illustrations and a handwritten hint
    src/assets/images/spendseer-redesign-two-factor.png, The two-factor page, with a box for each digit
{% endslideshow %}

## A Sticker Book

Since I was already leaning into stickers, I added a sticker book. You earn stickers for milestones like your first import, staying under budget a few months in a row, reaching a savings goal, or paying down a loan. A new one shows up on the dashboard with a little confetti. It's a small thing, but it's nice to get a pat on the back for staying on budget.

If that's not your thing, you can turn stickers off.

{% image "./src/assets/images/spendseer-redesign-sticker-book.jpg", "SpendSeer sticker book with earned stickers and grey placeholders for the ones still to collect", "(min-width: 768px) 600px, 100vw" %}

## Same Lesson as the Site

Just like with this site, trying ideas was cheap. The sidebar first had binder holes down the edge, and they didn't fit, so it became torn paper. I compared a few styles for the active page and the form fields side by side before picking one. I almost switched icon sets, looked at the options on the real pages, and stuck with what I had on lighter paper buttons.

It still needed someone to actually look at it. I caught a progress bar that read as two separate bars, chart tooltips that still looked like the old app, a badge that sat slightly off-center, and pie chart icons that didn't make sense where they were. None of them were hard to fix, but I only found them by clicking around.

## A New Tour

The old product tour showed the old design, and I wasn't happy with my own voiceover, so I re-recorded it. This time the narration is an AI voice ([Kokoro](https://huggingface.co/hexgrad/Kokoro-82M)) running on the same laptop I use for my [3D asset pipeline](https://wildcatprojects.com/projects/local-asset-forge/). Recording the tour turned up a real bug, too: importing an OFX file from a bank SpendSeer didn't recognize failed, so that got fixed along the way.

## Takeaway

SpendSeer started out trying to look like the finance app I thought it should be. Now that it's for me, it looks like something I actually enjoy opening, and that makes it a lot easier to keep using.

Until next time, keep on building!
