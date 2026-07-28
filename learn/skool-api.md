---
title: "Skool API — The Complete Unofficial API for Skool Communities (2026)"
description: "Skool has no official API. This is the complete unofficial Skool API — read posts, members, classroom, courses, AND write. Apify-hosted, production-grade."
slug: /learn/skool-api
type: glossary
primary_keyword: "skool api"
search_volume_monthly: 140
funnel: A
playbook: glossary
last_updated: 2026-05-19
canonical: https://skool-api.cristiantala.com/learn/skool-api/
---


> **TL;DR.** [Skool](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) does **not publish an official API**. The complete unofficial Skool API is the **[Skool All-in-One API actor on Apify](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=glossary&utm_campaign=skool-api&fpr=cristian)** — it covers read and write across posts, comments, members, classroom (courses/folders/pages), files, and group settings. One JSON POST per action, works from cURL, n8n, Make.com, Zapier, Python, or any LLM agent.

## Does Skool have an official API?

**No.** As of May 2026, Skool has not published an official, documented public API. There are no `/api/v1/...` REST endpoints with OAuth credentials, no developer portal, no API key system.

What Skool *does* expose, technically:

- A private internal API at `api.skool.com` used by the web app itself (`www.skool.com`) and the mobile apps. Not documented. Not stable across releases. Protected by cookies + AWS WAF token + dynamic Skool `buildId` that rotates approximately weekly.
- Zapier and Make.com integrations marked as "by Skool" — but these are **limited triggers** (new member, new post) with **no write actions** beyond a couple of webhooks. You cannot programmatically create courses, approve members, or post.
- A no-op "Skool API" listing on RapidAPI and similar marketplaces that's effectively a thin scraper with frequent breakage.

This gap is why the **unofficial Skool API** ecosystem exists.

## What is the Skool All-in-One API actor?

A production-grade reverse-engineered wrapper around Skool's internal API, deployed as an [Apify actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=glossary&utm_campaign=skool-api&fpr=cristian). One JSON POST per action. The actor handles:

- **Authentication** — Playwright login flow, cookies caching (3.5-day TTL), AWS WAF token rotation
- **`buildId` discovery** — Skool ships a new front-end build approximately every week; the actor auto-detects and adapts
- **Error structure** — every call returns either `{success: true, data: ...}` or `{success: false, errorCode, errorCategory, hint, retryable}`. Never throws.
- **Rate limiting** — Skool caps writes at ~25/min; the actor queues internally
- **Pay-per-event pricing** — no flat fee, no surprise bills. ~$0.005 per read, ~$0.01 per write.

```bash
curl -X POST "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=YOUR_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "action": "auth:login",
    "email": "admin@yourcommunity.com",
    "password": "your-skool-password",
    "groupSlug": "your-community-slug"
  }'
```

Returns:

```json
{
  "success": true,
  "cookies": "auth_token=...; client_id=...; aws-waf-token=...",
  "expiresAt": "2026-05-22T17:00:00Z",
  "buildId": "..."
}
```

You save the `cookies` string and pass it in every subsequent call instead of email/password.

## What can you do with the Skool API?

| Resource | Read | Write |
|---|---|---|
| **Posts** | List, filter (`unanswered`, `since`, `labelId`), paginate, get single, full comment trees | Create, update, delete, pin, unpin, like |
| **Comments** | Nested trees via REST (~35 in one call) OR the full thread via cursor pagination (no cap, $0.05) | Create top-level + nested, edit, delete |
| **Members** | List active, list pending applicants | Approve, reject, ban, batch-approve |
| **Events** | List all calendar events, list upcoming with next-occurrence + timezone | — |
| **Classroom** | List courses, full tree, single page | Create course/folder/page, set body (markdown→TipTap auto), update cover/title/desc/privacy/tier, update Resources, delete |
| **Files** | — | Upload cover images AND upload private files (PDF/JSON/ZIP) for classroom Resources |
| **Groups** | Get group metadata + label_options | Update Auto DM message |
| **System** | Health check + SSR debug diagnostics | — |

**36 actions total** as of v0.3.25 — see the [full actions reference](../docs/actions.md) for the exact `params` per action.

## Common Skool API use cases

- **Auto-approve members** with LLM screening — [recipe](../recipes/auto-approve-members-n8n.md)
- **Reply to unanswered posts** automatically — [recipe](../recipes/reply-unanswered-posts.md)
- **Publish entire courses from markdown** files — [recipe](../recipes/publish-course-from-markdown.md)
- **Set / update Auto DM** for new members — [recipe](../recipes/auto-dm-new-members.md)
- **Mirror your newsletter** to a Skool community post — [recipe](../recipes/newsletter-to-skool-post.md)
- **Batch update course covers** without resetting privacy/tier — [recipe](../recipes/batch-update-course-covers.md)

## Skool API for AI agents (Claude, GPT, MCP)

The actor is designed to be called from **AI agent loops** without custom glue code.

- **One action per HTTP call** — every operation is a stateless POST. Idempotent retries are safe (except for `posts:create` which is naturally non-idempotent).
- **Function-calling spec** — see [AI Agents integration guide](../docs/agents.md) for Claude tool definitions, OpenAI function schemas, and a sample LangChain `Tool` wrapper.
- **MCP server compatibility** — the actor's `system:health` + structured action contract maps cleanly to an MCP tool. See [Skool MCP server](../integrations/skool-mcp-server.md).
- **Never-throw contract** — agents that branch on response don't need try/catch around each call. Failures come back as `{success: false, hint: "do this next"}`.

This is why agents at `claude.ai` and `mcp.apify.com` have started routing Skool-related queries directly to the actor.

## Common questions

### Is the Skool API free?

The actor itself is open to use on Apify with pay-per-event pricing — ~$1.50/mo for a typical small community (50 writes + 200 reads per day). No subscription. Apify free tier covers most personal use. [See live pricing](https://apify.com/cristiantala/skool-all-in-one-api?fpr=cristian).

### Will Skool break the API?

The actor adapts automatically to Skool's weekly `buildId` rotation and WAF token cycling. When Skool ships a structurally breaking change (~1-2 times per year historically), updates ship to the actor within hours and Apify auto-pulls `latest`. The actor's source has been continuously maintained since [first release](https://github.com/ctala/skool-api-docs/blob/main/CHANGELOG.md).

### Is using this against Skool's terms?

You authenticate as a Skool user that owns or admins the community. You're using your own credentials to automate your own community. This is not scraping arbitrary public data or pretending to be someone else. Don't use the actor against communities you don't own or admin — that's not what it's for.

### How does it compare to writing my own Playwright scraper?

A custom scraper means: maintaining the WAF token cycle, the `buildId` discovery, the cookies persistence, the rate-limit queue, the structured error layer, AND the ~30 endpoints across posts/members/classroom/files. That's a ~3K-line, ~50-hour project — and then it breaks when Skool ships a deploy and you spend Saturday debugging. The actor handles all of that for ~$1.50/mo. See [Skool API vs custom scraper](../automation/skool-scraper.md).

## Related

- [Authentication](../docs/authentication.md) — cookies, WAF tokens, the `x402-payment-required` confusion
- [Actions reference](../docs/actions.md) — every action with required params
- [Posts & Comments](../docs/posts.md) — the data model, `parentId` vs `rootId`
- [AI Agents integration](../docs/agents.md) — Claude / OpenAI / MCP / LangChain specs
- [Recipes](../recipes/) — copy-paste-ready integrations

---

## Use it in production today

[**→ Open the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=glossary&utm_campaign=skool-api&fpr=cristian)

- Pay-per-event pricing — ~$1.50/mo for typical use
- Read AND write — posts, comments, members, classroom, files, groups
- Never-throw contract — every failure is a structured response, not an exception
- Battle-tested in production

*New to Skool? [Launch your community here](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "DefinedTerm",
  "name": "Skool API",
  "description": "The complete unofficial Skool API for read and write operations on Skool community posts, comments, members, classroom, and files. Apify-hosted actor with pay-per-event pricing.",
  "inDefinedTermSet": "https://github.com/ctala/skool-api-docs",
  "url": "https://github.com/ctala/skool-api-docs/blob/main/learn/skool-api.md"
}
</script>
