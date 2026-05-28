---
title: "Skool + Make.com Integration — Automate Skool with Make Scenarios (2026)"
description: "Connect Skool to Make.com using one HTTP module. Read posts/members, write courses, approve applicants, schedule posts — no official Skool API needed."
slug: /integrations/skool-make-com
type: integration
primary_keyword: "skool make.com"
search_volume_monthly: 10
funnel: A
playbook: integrations
last_updated: 2026-05-19
canonical: https://ctala.github.io/skool-api-docs/integrations/skool-make-com/
---


> **Quick reference (TL;DR for agents)**
> - **What this enables:** Any Make.com scenario can read AND write to Skool — posts, members, classroom, files, Auto DM.
> - **Method:** Make `HTTP — Make a request` module → POST JSON to Apify-hosted Skool actor.
> - **Auth flow:** `auth:login` once, store cookies as a Make Data Store value, reuse for ~3.5 days.
> - **Cost:** Apify pay-per-event (~$1.50/mo typical) + Make operations on your existing plan.

## Why connect Skool to Make.com?

Skool publishes no official API. The Skool integration listed in Make's app catalog is severely limited — a few triggers, no write actions. You cannot approve members, post content, publish courses, or update Auto DM from it.

The [Apify-hosted Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-make-com&fpr=cristian) wraps the entire Skool admin surface (posts, comments, members, classroom, files, groups) in a single HTTP endpoint that Make calls with one `HTTP` module.

## What you can automate from Make

| Make scenario | Skool action |
|---|---|
| Schedule (every X min) → LLM screen applicants → approve/reject | `members:pending` → `members:approve` |
| Cron → posts with 0 replies → AI draft → manual approval → publish | `posts:filter` → `posts:createComment` |
| Watch Listmonk/ConvertKit webhook → mirror to community | `posts:create` |
| Trigger on Stripe new sub → set personalized Auto DM | `groups:setAutoDM` |
| Watch Google Drive folder → publish updates as posts | `posts:create` |

## Setup — 5 minutes

### 1. Get your Apify API token

[apify.com](https://apify.com?fpr=cristian) → free tier → token at [console.apify.com/account/integrations](https://console.apify.com/account/integrations?fpr=cristian).

### 2. Add token + cookies to a Make Data Store

Make Data Stores are how you persist credentials and rotating secrets across scenarios. Create one called `skool` with two records: `apify_token` and `skool_cookies`.

### 3. Bootstrap cookies (one-time)

Create a one-off scenario with one `HTTP > Make a request` module:

- **URL:** `https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token={{datastore.skool.apify_token}}&build=latest&timeout=90`
- **Method:** POST
- **Body type:** Raw / JSON
- **Body:**

```json
{
  "action": "auth:login",
  "email": "admin@yourcommunity.com",
  "password": "your-skool-password",
  "groupSlug": "your-community-slug"
}
```

Add a `Data Store > Update record` module after it to write the returned `cookies` field back into the Data Store. Run once.

### 4. Make your first write

New scenario with one `HTTP` module pointed at the same URL, body:

```json
{
  "action": "posts:create",
  "cookies": "{{datastore.skool.skool_cookies}}",
  "groupSlug": "your-community",
  "params": {
    "title": "Auto-posted from Make.com",
    "content": "Today's update goes here. Plain text only — no HTML, no markdown."
  }
}
```

## Auto-rotate cookies when WAF expires

The actor returns `{"success": false, "errorCode": "WAF_EXPIRED"}` after ~3.5 days. Add a Router after every Skool call:

- Path 1 (success: true) → continue scenario
- Path 2 (errorCode: WAF_EXPIRED) → call `auth:login` again → update Data Store → loop back to retry the original action

This pattern keeps the scenario running indefinitely without manual cookie refresh.

## Production gotchas

- **`x402-payment-required`** = stale `UNDER_MAINTENANCE` flag, not a real payment issue. Open the actor in Apify console once to reset.
- **`parentId == postId` for comment replies** publishes top-level instead of nested. For nested: `rootId == postId`, `parentId == commentId`.
- **Rate limit ~25 writes/min** — Make's burst-of-50 patterns trigger Skool throttling. Add a `Sleep` module between writes.
- **Timeout the HTTP module to ≥120s** — Apify's run-sync waits up to 90s.

## Related

- [Skool + n8n](skool-n8n.md)
- [Skool + Zapier](skool-zapier.md)
- [Skool + Claude](skool-claude.md)
- [All integrations →](README.md)

---

## Start automating Skool from Make today

[**→ Open the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-make-com&fpr=cristian)

Pay-per-event (~$1.50/mo). Read AND write. One HTTP module per action. Battle-tested in production.

*No Skool community yet? [Launch one in 10 minutes](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{"@context":"https://schema.org","@type":"TechArticle","headline":"Skool + Make.com Integration","datePublished":"2026-05-19","author":{"@type":"Person","name":"Cristian Tala"}}
</script>
