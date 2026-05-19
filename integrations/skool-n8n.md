---
title: "Skool + n8n Integration — Automate Your Skool Community with n8n (2026)"
description: "Connect Skool to n8n using one HTTP node. Auto-approve members, reply to posts, schedule announcements, sync data. No official Skool API needed."
slug: /integrations/skool-n8n
type: integration
primary_keyword: "skool n8n"
search_volume_monthly: 10
funnel: A
playbook: integrations
last_updated: 2026-05-19
canonical: https://github.com/ctala/skool-api-docs/blob/main/integrations/skool-n8n.md
render_with_liquid: false
---


> **Quick reference (TL;DR for agents)**
> - **What this enables:** Any n8n workflow can read AND write to Skool — posts, comments, members, classroom, files, Auto DM.
> - **Method:** n8n `HTTP Request` node → POST JSON to Apify-hosted Skool actor → Skool internal API.
> - **Auth flow:** `auth:login` once, store `cookies` in n8n Credentials, reuse for ~3.5 days.
> - **Latency:** ~2s per call (cookies cached) / ~10s (email+password each call).
> - **Cost:** Apify pay-per-event (~$1.50/mo for typical communities) + your n8n hosting.
> - **n8n template:** [Auto-Approve Skool Members with GPT-4o AI Screening](https://n8n.io/workflows/14392-auto-approve-skool-community-members-with-gpt-4o-ai-screening/) — published, ready to import.

## Why connect Skool to n8n?

Skool has **no official API** and the existing "Skool by Skool" Zapier/n8n connector only triggers on a few events (new member, new post) — it doesn't write. You can't approve members, post content, publish courses, or update Auto DM from it.

The [Apify-hosted Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-n8n) wraps the entire Skool admin surface (posts, comments, members, classroom, files, groups) in a single HTTP endpoint. From n8n you call it with one `HTTP Request` node.

## What you can automate from n8n

| n8n flow | Skool action | Recipe |
|---|---|---|
| Schedule trigger → LLM screen → approve/reject | `members:pending` → `members:approve` | [Auto-approve members](../recipes/auto-approve-members-n8n.md) |
| Cron → posts with 0 replies → AI draft → Telegram approval → publish | `posts:filter` → `posts:createComment` | [Reply unanswered](../recipes/reply-unanswered-posts.md) |
| Listmonk/ConvertKit campaign sent → mirror to community feed | `posts:create` | [Newsletter to Skool](../recipes/newsletter-to-skool-post.md) |
| Webhook (Stripe / new signup) → set personalized Auto DM | `groups:setAutoDM` | [Auto DM new members](../recipes/auto-dm-new-members.md) |
| Markdown files in Git → full course in Skool classroom | `classroom:createCourse` + `classroom:setBody` | [Publish course from markdown](../recipes/publish-course-from-markdown.md) |
| Schedule → batch refresh course covers via R2/S3 URLs | `files:uploadImage` + `classroom:updateCourse` | [Batch update covers](../recipes/batch-update-course-covers.md) |

## Architecture

```
n8n                                Apify                       Skool
───                                ─────                       ─────
[Cron / Webhook trigger]
       │
       ▼
[HTTP Request node ─────POST JSON────→ run-sync-get-dataset-items ──→ api.skool.com]
{ action, cookies, ... }                                              (cookies + WAF + buildId
       │                                                              handled by actor)
       ◄────────────── { success: true, data: ... } ◄────────────────┘
```

Every Skool operation = one HTTP POST. No SDK to install in n8n. No node to develop. Idempotent retries are safe.

## Setup — 5 minutes

### 1. Get your Apify API token

Sign up at [apify.com](https://apify.com) (free tier covers most personal use). Token from [console.apify.com/account/integrations](https://console.apify.com/account/integrations).

### 2. Store the token in n8n Credentials

n8n → Credentials → New → Header Auth:

- **Name:** `Apify Token`
- **Header name:** `Authorization`
- **Header value:** *(leave empty — token goes in the URL query string)*

(Alternatively, use n8n's HTTP Query Auth and put the token in the URL.)

### 3. Bootstrap your Skool cookies (one-time, valid ~3.5 days)

In n8n, create a one-off workflow with a single `HTTP Request` node:

- **Method:** `POST`
- **URL:** `https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token={{$credentials.apifyToken}}&build=latest&timeout=90`
- **Body:** JSON

```json
{
  "action": "auth:login",
  "email": "admin@yourcommunity.com",
  "password": "your-skool-password",
  "groupSlug": "your-community-slug"
}
```

Execute once. Copy the `cookies` field from the response. Save it as a new n8n Credential called `Skool Cookies`. Plan to rotate it every ~3.5 days (or branch on `WAF_EXPIRED` error and call `auth:login` automatically — see Production gotchas).

### 4. Make your first write — post a community update

Create a new workflow with one `HTTP Request` node:

- **Method:** `POST`
- **URL:** `https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token={{$credentials.apifyToken}}&build=latest&timeout=90`
- **Body:** JSON

```json
{
  "action": "posts:create",
  "cookies": "{{$credentials.skoolCookies}}",
  "groupSlug": "your-community",
  "params": {
    "title": "Workflow shipped today",
    "content": "Just shipped the auto-approval workflow. It now screens applicants with GPT-4o before approving. Saved me 30 minutes today.",
    "labelId": null
  }
}
```

Done. The new post appears in your community feed within 1-2 seconds.

## Example: the n8n auto-approve template

I [published this workflow as an official n8n template](https://n8n.io/workflows/14392-auto-approve-skool-community-members-with-gpt-4o-ai-screening/) — clone it directly into your n8n.

**Flow:**

1. **Webhook** receives Skool's "new applicant" notification (or schedule polls `members:pending` every 5 min if you don't have a Skool webhook)
2. **Function** extracts applicant LinkedIn + answers from the apply form
3. **OpenAI/Claude/Anthropic node** screens against your criteria (returns `approve | reject | review`)
4. **Switch** branches on the LLM verdict
5. **HTTP Request** to `members:approve` or `members:reject`
6. **Telegram / Slack** notifies you with the verdict + member info

Cost: ~$0.02 per applicant in LLM + ~$0.01 per Skool call. For 30 applicants/week: ~$5/mo.

## Production gotchas

- **`x402-payment-required` on every call:** Not a payment issue. It's a stale `notice:UNDER_MAINTENANCE` flag Apify sets via internal heuristic when an actor has high error rates briefly. Open the actor page once in Apify console to reset, or use the `unbreak.sh` recovery flow described in [error handling](../docs/error-handling.md).
- **`WAF_EXPIRED` error:** Your cookies have aged past the WAF token rotation window (~3.5 days). Branch your workflow: on this error → call `auth:login` → update the `Skool Cookies` credential → retry. n8n's "Continue on fail" + error workflow pattern handles this cleanly.
- **`parentId == postId` for nested replies returns silent failure:** For comment replies inside a thread, `rootId == postId` (always) and `parentId == commentId` (the comment you reply to). Confusing them publishes the reply at top level instead of nested.
- **Rate limit ~25 writes/min:** Skool's hard limit. The actor queues internally — don't add your own retry loop. If your n8n workflow generates more than 25 writes/min, batch them with a wait or use `members:batchApprove` which Skool handles server-side.
- **n8n HTTP node timeout:** Default is 60s. The actor's `run-sync` endpoint waits up to 90s in the URL (`&timeout=90`). Set the n8n node timeout to ≥120s to leave room for the Apify queue.

## Full workflow JSON — minimal "post on schedule"

<details>
<summary>Click to expand</summary>

```json
{
  "name": "Skool — daily community update",
  "nodes": [
    {
      "parameters": {
        "rule": {"interval": [{"field": "hours", "hoursInterval": 24}]}
      },
      "id": "1",
      "name": "Daily 9am",
      "type": "n8n-nodes-base.scheduleTrigger",
      "typeVersion": 1.1,
      "position": [200, 300]
    },
    {
      "parameters": {
        "method": "POST",
        "url": "=https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token={{$credentials.apifyToken}}&build=latest&timeout=90",
        "sendBody": true,
        "specifyBody": "json",
        "jsonBody": "={\n  \"action\": \"posts:create\",\n  \"cookies\": \"{{$credentials.skoolCookies}}\",\n  \"groupSlug\": \"your-community\",\n  \"params\": {\n    \"title\": \"Daily standup — {{$now.toFormat('LLL dd')}}\",\n    \"content\": \"What are you shipping today? Drop it in this thread.\"\n  }\n}",
        "options": {"timeout": 120000}
      },
      "id": "2",
      "name": "Post to Skool",
      "type": "n8n-nodes-base.httpRequest",
      "typeVersion": 4.2,
      "position": [500, 300]
    }
  ],
  "connections": {
    "Daily 9am": {"main": [[{"node": "Post to Skool", "type": "main", "index": 0}]]}
  }
}
```

</details>

## Related integrations

- [Skool + Make.com](skool-make-com.md)
- [Skool + Zapier](skool-zapier.md)
- [Skool + Claude (AI agent)](skool-claude.md)
- [Skool + MCP server](skool-mcp-server.md)
- [Skool + Python](skool-python.md)
- [All integrations →](README.md)

---

## Start automating Skool from n8n today

[**→ Open the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-n8n)

- Pay-per-event (~$1.50/mo for typical community automation)
- Read AND write — full API surface
- One n8n `HTTP Request` node per action
- Battle-tested in production on a 484-member Skool community

*No Skool community yet? [Launch one in 10 minutes](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "TechArticle",
  "headline": "Skool + n8n Integration",
  "description": "Connect Skool to n8n using the Apify-hosted Skool API actor. One HTTP Request node, read and write to posts, members, classroom, courses, files.",
  "datePublished": "2026-05-19",
  "author": {"@type": "Person", "name": "Cristian Tala", "url": "https://cristiantala.com"}
}
</script>
