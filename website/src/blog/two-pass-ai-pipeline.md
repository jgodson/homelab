---
title: "Accuracy over Speed: Experimenting with a Two-Pass AI Pipeline for Local LLMs"
description: How I tested whether server-local AI could handle financial document extraction well enough to avoid relying on a large hosted model API.
date: 2026-05-22
tags:
  - ai
  - llm
  - spendseer
  - infrastructure
layout: post.njk
---

I started this project with a practical question for [SpendSeer](https://app.spendseer.com): could server-local AI extract useful transaction data from bills and receipts, or would this be the kind of feature where paying for a large hosted model API is simply the right answer?

I wanted the local option to work. It would give me more control over cost, latency, and document handling. But financial imports are not a forgiving AI use case. A model that is "mostly right" can still create more work than it saves if it pulls the wrong total or turns a grocery receipt into twenty noisy line items.

My first attempts used the obvious approaches: extracting raw text directly from PDFs, or asking a single local vision model to look at an image and output structured JSON in one shot. Those worked occasionally, but complex documents like multi-page utility bills and long retail receipts exposed the gap quickly. The models hallucinated total amounts, extracted individual products instead of receipt totals, or failed to associate taxes with the services they belonged to.

That changed the experiment. I stopped asking whether a local model could solve the whole problem by itself and started asking how much structure, direction, and deterministic cleanup it needed around it. That led to a deliberate two-pass hybrid pipeline.

## The Problem with Single-Pass Extraction
Those early single-pass attempts broke down across two paths:
1. **For PDFs:** I extracted the raw text layer and sent it to an LLM.
2. **For Images:** I sent them to local Vision-Language Models (VLMs) like `llama3.2-vision` or `llava` and asked for JSON.

Both approaches had major weaknesses when it came to financial data extraction:

- **Loss of Spatial Reasoning:** The raw PDF text extraction completely destroyed the visual formatting (columns, tables). The LLM couldn't figure out which tax applied to which line item because the layout was lost.
- **JSON Precision vs. OCR:** Forcing a vision model to handle both high-fidelity OCR (Optical Character Recognition) and complex JSON reasoning in a single context often led to "hallucinated" numbers or broken syntax.

In one early single-pass vision benchmark, the whole 19-document corpus scored **0%**. My Enmax utility bills were the clearest failure case: the model could see pieces of the bill, but it kept mixing up service subtotals, taxes, municipal charges, and grand totals.

## The Solution: The Two-Pass Pipeline
The breakthrough came when I realized I needed to preserve the visual layout of PDFs, but separate the **Transcription** pass from the **Reasoning** pass. By letting each model do exactly what it is best at, then backing that up with deterministic cleanup in the parser, the results improved dramatically.

### Pass 1: Transcription (The "Vision" Pass)
Instead of asking the model for JSON, SpendSeer converts the document into visual input and asks for a raw, layout-preserving text dump. PDFs are converted to PNGs first; images are sent directly.

I benchmarked `llama3.2-vision` against `glm-ocr:bf16`. While their single-pass accuracy was similar, `glm-ocr` was the clear winner for transcription. It is specifically fine-tuned for OCR tasks and handled dense, multi-page utility bills reliably without "summarizing" the text prematurely.

-   **Model:** `glm-ocr:bf16`
-   **Prompt:** *"Transcribe every word and number on this document exactly as it appears. Maintain the relative layout if possible. Do not summarize or format as JSON, just provide the raw text."*
-   **Goal:** Fidelity. We want a text-based representation of the image that preserves columns and service sections.

### Pass 2: Reasoning (The "Text" Pass)
Now that we have a layout-preserved text representation, SpendSeer sends it to a larger reasoning model to structure the JSON. The current parser also detects document profiles, retries multi-service utility summaries when reconciliation fails, and applies deterministic cleanup before rows are saved.

I tested `llama3.1:8b`, `qwen2.5:7b`, and `gpt-oss:20b`. The `gpt-oss:20b` model significantly outperformed the smaller models. It had a much better understanding of financial subtotals versus grand totals, and it didn't struggle with complex JSON formatting.

-   **Model:** `gpt-oss:20b`
-   **Prompt Tweaks:** I had to explicitly add strict negative constraints to prevent "retail over-extraction" (e.g., *"ABSOLUTELY FORBIDDEN: Do not extract individual products like 'Apples'. Extract EXACTLY ONE item representing the total transaction."*) and explicit instructions to look for separated taxes at the bottom of service sections.
-   **Goal:** Extraction. This model identifies the merchant, dates, service totals, and receipt totals while avoiding noisy line-item over-extraction.

## Benchmarking Results
To verify this, I built a local evaluation framework that benchmarks these strategies against a "Ground Truth" dataset of my own bills and receipts.

The exact numbers moved around as I kept improving the parser, but the overall result held: the two-pass pipeline was materially better than the original single-pass experiments, especially on utility bills where taxes and subtotals are visually separated.

The strongest baseline I kept from those experiments was:

- **Model Pair:** `glm-ocr:bf16` + `gpt-oss:20b`
- **Corpus Accuracy:** **94.7%**
- **Average Latency:** **96.93 seconds**
- **Eval Corpus Size:** `19` documents

That score is based on matching imported rows against ground truth totals. The ground truth records base amount plus tax separately, but SpendSeer imports the all-in row amount because transactions care about the final amount paid.

The results on the Enmax utility bills were the most impressive. In the early single-pass attempts, models often extracted one visible number but lost the relationship between electricity, natural gas, city utility sections, taxes, and grand totals. With the two-pass pipeline, the parser can use the layout-preserved transcription from `glm-ocr` to reconcile a $251.88 Electricity subtotal plus $12.59 GST into the correct $264.47 imported row.

## The Trade-off: Latency
Nothing is free. By moving to two passes, converting PDFs to images first, and using a larger 20b model for reasoning, I took a massive hit on performance:

-   **Early One-Pass / Raw-Text Attempts:** <30s, but not accurate enough
-   **Current Two-Pass Average:** **~97 seconds** across the eval corpus

In a synchronous web request, this would be a disaster. Even asynchronously, it is expensive enough that I would need to limit background job concurrency so the extraction pipeline does not overwhelm the server-local Ollama instance before I could scale that up.

## Infrastructure & Implementation
The pipeline uses **Ollama** running locally to the server doing the extraction. To make the experiments realistic, I pushed far enough into the implementation to convert PDFs with `pdftoppm`, queue extraction in GoodJob, and evaluate the workflow end-to-end instead of only testing prompt snippets in isolation.

One issue I ran into was file handoff. The web app and the background worker run in separate pods, so handing the worker a pod-local temp file path does not work reliably. To avoid requiring a S3 storage provider just for this, I ended up building a tiny internal blob handoff service so the web process can upload the file, the worker can download it, and the worker can delete the blob after processing. If that service is not running, AI extraction fails fast.

## Import Flow
From the user side, I wanted this to feel like the existing import flow: upload a document, let the async worker do its thing, then review the draft rows before committing anything. The final image is the kind of bill the pipeline needs to understand underneath that flow.

{% slideshow %}
    src/assets/images/spendseer-ai-extraction-demo-1.png, Starting an AI extraction from the transaction import form
    src/assets/images/spendseer-ai-extraction-demo-2.png, Import batch processing while the worker extracts rows
    src/assets/images/spendseer-ai-extraction-demo-3.png, Completed draft import ready for review before committing
    src/assets/images/spendseer-ai-extraction-demo-bill.png, Example bill document used as extraction input
{% endslideshow %}

The parser path I ended up preferring is now the feature-flagged path:
1.  **PDFs:** Convert the first 3 pages (where totals usually live) to high-res PNGs using `pdftoppm`.
2.  **Images:** Use the uploaded image directly.
3.  **Vision Pass:** Loop through each visual input and get a raw transcription from `glm-ocr`.
4.  **Text Pass:** Feed the aggregate transcription into `gpt-oss:20b` for structured extraction.
5.  **Post-processing:** Normalize labels, reconcile utility summaries, resolve source metadata, and create draft import rows for review.
6.  **Cleanup:** Wipe temporary conversion files and delete the uploaded handoff blob after processing.

## Final Thoughts
I started this work trying to answer a simple question: could server-local AI handle this well enough, or would I need to pay for a large hosted model API to get reliable results?

My answer at this point is: probably, but not casually. The experiments convinced me that local extraction can work, but only with a lot more guardrails and direction than a naive "send the bill to a model and ask for JSON" approach. Layout preservation matters. Explicit evaluation matters. Deterministic cleanup matters. The model needs to be guided toward the exact financial shape SpendSeer expects.

That is why this is staying behind a feature flag for now. It feels possible, and the early results are strong enough that I want to keep pushing on it, but I am going to test it more thoroughly against real imports before committing it as a generally available SpendSeer feature.
