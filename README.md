# Skool API — Read AND Write, on Apify

> **The most complete unofficial Skool API.** Read posts, comments, members, and courses. Create posts, reply to comments, approve members, build entire courses programmatically. Drop-in for n8n, Make.com, Zapier, AI agents.

[![Apify Actor](https://img.shields.io/badge/Apify-Actor-FF9900?logo=apify&logoColor=white)](https://apify.com/cristiantala/skool-all-in-one-api?fpr=cristian)
[![Latest version](https://img.shields.io/badge/version-0.3.25-brightgreen)](https://apify.com/cristiantala/skool-all-in-one-api?fpr=cristian)
[![n8n template](https://img.shields.io/badge/n8n-template-EA4B71?logo=n8n&logoColor=white)](https://n8n.io/workflows/14392-auto-approve-skool-community-members-with-gpt-4o-ai-screening/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

```
┌─────────────────┐
│ Your stack      │  ──┐
│  - n8n          │    │
│  - Make.com     │    │
│  - AI agents    │    │     ┌────────────────────────┐         ┌────────────────┐
│  - Custom code  │    ├──→  │  Apify Actor           │  ──→    │  Skool API     │
└─────────────────┘    │     │  Skool All-in-One API  │         │  (cookies +    │
                       │     │  read · write · auth   │         │  WAF + buildId │
                       │     └────────────────────────┘         │  handled for   │
                       │                                        │  you)          │
                       └→  POST action:operation                 └────────────────┘
                          → structured response
```

## Why this exists

Skool **does not have an official API**. The community has reverse-engineered bits and pieces, but nobody has shipped a complete, write-capable, auth-handled, production-ready integration that AI agents and no-code tools can use.

This actor is that integration. It powers a real production community ([Cágala, Aprende, Repite](https://www.skool.com/cagala-aprende-repite/about) — daily writes, automated onboarding, full classroom). If it breaks, it breaks for me first. Bugs get fixed fast.

### Built by a solo community admin, for solo community admins

I run my community alone — no team, no virtual assistants, no community managers on staff. Everything in this doc-site exists because **I needed it to keep up with the daily work** of running a Skool community as a one-person operation: approving members, replying to posts, publishing courses, sending event reminders, exporting member data for follow-up.

If you're a solo founder or admin trying to grow a Skool community without burning out on repetitive admin clicks — this is built for you. Every recipe is something I run in my own production. If a flow doesn't work for me with my actual time budget, it doesn't ship.

## What you can do

| Resource | Read | Write |
|---|---|---|
| **Posts** | List, filter, paginate, get single, get full comment trees | Create, update, delete, pin, unpin, like |
| **Comments** | Nested trees with replies | Create top-level + nested replies, edit, delete |
| **Members** | List active, list pending applicants | Approve, reject, ban, batch-approve |
| **Classroom** | List courses, full tree, single page | Create course, folder, page, set body (markdown→TipTap), update cover/title/description, delete |
| **Files** | — | Upload images for course covers |
| **Groups** | Get group info | Update description, update Auto DM message |

[See full action reference →](docs/actions.md) · [Use it from AI agents (Claude / OpenAI / MCP) →](docs/agents.md)

## Quick start (60 seconds)

### 1. Get an Apify account

Sign up at [apify.com](https://apify.com?fpr=cristian) (free tier covers most personal use). Grab your API token from the [account dashboard](https://console.apify.com/sign-up?fpr=cristian).

### 2. Run your first call

```bash
curl -X POST "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=YOUR_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "action": "auth:login",
    "email": "your-skool-email@example.com",
    "password": "your-skool-password",
    "groupSlug": "your-community"
  }'
```

The response includes a `cookies` string. **Save it** — for the next ~3.5 days you can pass it instead of email/password and skip the slow Playwright login (~2s vs ~10s per call).

### 3. Use the cookies for everything else

```bash
curl -X POST "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=YOUR_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "action": "posts:list",
    "cookies": "auth_token=...; client_id=...; aws-waf-token=...",
    "groupSlug": "your-community",
    "params": { "page": 1 }
  }'
```

[Full Getting Started guide →](docs/getting-started.md)

## Browse by topic

This repo is organized into 8 sections. Each section has its own README hub.

| Section | What's there |
|---|---|
| 📘 **[Learn](learn/)** | Glossary — what is the Skool API, how does Skool work, features, classroom, courses, affiliate program, live events |
| 🛠️ **[Integrations](integrations/)** | Tool-specific guides — n8n, Make.com, Zapier, Claude, GPT, MCP, Python, LangChain, Webhooks |
| 🤖 **[Automation](automation/)** | Strategic overview — bot vs agent, building a Skool bot, building a Skool AI agent, why not to build your own scraper |
| 🍳 **[Recipes](recipes/)** | Cookbook — copy-paste workflows for auto-approve, reply unanswered, publish course from markdown, more |
| 🔍 **[Compare](compare/)** | Skool vs X — Circle, Mighty Networks, Kajabi, Teachable, Thinkific, Discord, Slack, alternatives |
| 📖 **[Guide](guide/)** | Founder decisions — is Skool legit, is Skool worth it, pricing, free trial, reviews, how to start |
| 🎯 **[For X](for/)** | Audience-specific — Skool for AI agents (more coming) |
| 📚 **[Docs](docs/)** | Reference — authentication, actions, posts, members, classroom, files, groups, error handling, AI agents integration |

## Recipes

Real, copy-paste-ready integrations:

- [**Auto-approve Skool members with n8n + GPT-4o AI screening**](recipes/auto-approve-members-n8n.md) — published as a [ready-to-import n8n template](https://n8n.io/workflows/14392-auto-approve-skool-community-members-with-gpt-4o-ai-screening/). Webhook → AI screen → approve.
- [**Reply to unanswered posts automatically**](recipes/reply-unanswered-posts.md) — find posts with 0 comments, reply with on-brand AI message
- [**Publish a course from markdown files**](recipes/publish-course-from-markdown.md) — your local markdown → full Skool classroom with covers
- [**Auto DM new members**](recipes/auto-dm-new-members.md) — set/update the welcome message that triggers when someone joins
- [**Batch update course covers**](recipes/batch-update-course-covers.md) — refresh visual identity across N courses without resetting privacy/tier
- [**Newsletter to Skool post**](recipes/newsletter-to-skool-post.md) — mirror your Listmonk/ConvertKit newsletter as a community post
- [**Weekly changelog with poll + broadcast**](recipes/weekly-changelog-post-with-poll-and-broadcast.md) — image, poll and "email all members" in one post (and why a 200 proves none of them worked)
- [**Audit a long welcome thread (>35 comments)**](recipes/audit-welcome-thread-with-getcommentsfull.md) — bypass Skool's REST cap with `posts:getCommentsFull` to find members you haven't replied to yet
- [**Use the Skool API as MCP tool for Claude / Cursor / Cline**](recipes/use-skool-api-as-mcp-tool.md) — expose all 33 actions to your AI agents via Apify's hosted MCP server
- [**Community analytics: export Skool data to NocoDB / Airtable**](recipes/community-analytics-to-nocodb.md) — track engagement, churn, conversion to paid via your own BI tool

## Documentation

| Topic | What you'll learn |
|---|---|
| [Getting Started](docs/getting-started.md) | First call, auth flow, cookies caching |
| [Authentication](docs/authentication.md) | How auth works, WAF token rotation, the `x402-payment-required` "fake error" |
| [Posts & Comments](docs/posts.md) | Skool's post=comment data model, content formats, mentions |
| [Members](docs/members.md) | Approval flow, batch operations, member roles |
| [Classroom](docs/classroom.md) | Courses, folders, pages, the markdown→TipTap converter, the R-PUT-COURSE quirk |
| [Files](docs/files.md) | Image upload flow (cover images for courses) |
| [Groups](docs/groups.md) | Description, Auto DM, settings |
| [Error handling](docs/error-handling.md) | Structured `{success:false}` payloads, `errorCode` catalog, `hint` field, retry logic |
| [AI Agents integration](docs/agents.md) | Function-calling specs (Claude / OpenAI / Gemini), MCP server, LangChain Tool, Claude Code Skill, agent loop patterns |
| [Changelog](CHANGELOG.md) | Version history, what changed when |

## Pricing

The actor uses **Apify Pay-Per-Event** (PPE) — you pay only for what you use:

| Action | Approx. cost |
|---|---|
| `auth:login` (once every ~3.5 days) | ~$0.02 (Playwright login) |
| Read action (`posts:list`, `members:list`, etc.) | ~$0.005 |
| Write action (create post, approve member, etc.) | ~$0.01 + ~$0.005 platform |
| `files:uploadImage` | ~$0.005 |

A community handling ~50 writes + ~200 reads per day costs roughly **$1.50/month**. [See full pricing →](https://apify.com/cristiantala/skool-all-in-one-api?fpr=cristian)

## Reliability

- **Never-throw policy**: every error — including network failures and Skool 4xx responses — becomes a structured `{success:false}` payload pushed to the dataset, with an `errorCode` and `hint` field. Runs always end `SUCCEEDED`. The actor never trips Apify's `UNDER_MAINTENANCE` flag.
- **Daily Quality Check pass**: the actor's input schema defaults to `system:health` so Apify's automated daily test always passes — production callers stay unaffected by Apify-side checks.
- **Auto retry**: 5xx responses, network errors, expired WAF tokens, and stale buildIds are auto-handled with exponential backoff.
- [More on reliability →](docs/error-handling.md)

## What it's NOT

- ❌ Not an official Skool product. Skool may change behavior at any time. This actor is reverse-engineered from the public Skool web app, kept stable as Skool deploys (~weekly buildId rotation, auto-handled).
- ❌ Not for bypassing Skool's terms. You authenticate as a user that owns or admins the community. Don't scrape communities you have no access to.
- ❌ Not for spam. Skool's rate limits (~20-30 writes/min) are enforced. The actor respects them.

## Status

| | |
|---|---|
| **Latest version** | `0.3.25` — May 2026 |
| **Last battle-tested in production** | Daily, on `cagala-aprende-repite` |
| **Skool buildId rotation** | Auto-handled (~weekly) |
| **WAF token rotation** | Auto-handled (~3.5 days) |

[Changelog →](CHANGELOG.md)

## Issues & feature requests

The actor's source code is **not open-source** (commercial product), but this docs repo is. To report a bug or request a feature:

- 🐛 [Open a bug report](https://github.com/ctala/skool-api-docs/issues/new?template=bug-report.md)
- 💡 [Open a feature request](https://github.com/ctala/skool-api-docs/issues/new?template=feature-request.md)
- 💬 Discuss with the community in [Cágala, Aprende, Repite](https://www.skool.com/cagala-aprende-repite/about) (Spanish-speaking founders)

## Articles & deep dives

- 📝 [The Complete Skool API: 9 Months of Reverse-Engineering 33 Actions (n8n + TypeScript + AI Agents)](https://cristiantalasanchez.hashnode.dev/the-complete-skool-api-9-months-of-reverse-engineering-33-actions-n8n-typescript-ai-agents) — full technical deep-dive (May 2026)
- 📝 [I Built the Most Complete Skool API — and What I Learned Reverse-Engineering It](https://cristiantalasanchez.hashnode.dev/i-built-the-most-complete-skool-api-read-and-write-and-what-i-learned-reverse-engineering-it) — original launch post (March 2026)

## Related

- 🐦 Built by [Cristian Tala](https://cristiantala.com) — operator using AI to run a community of founders solo
- 🎓 [Cágala, Aprende, Repite](https://www.skool.com/cagala-aprende-repite/about) — the Skool community where this actor was forged
- 📰 [Tutorials & deep dives](https://cristiantala.com/blog) — recipes, lessons, case studies

## License

The contents of this repository (docs, recipes, examples) are licensed under [MIT](LICENSE) — copy, modify, embed in your projects freely.

The Apify actor itself (`skool-all-in-one-api`) is a commercial product, not covered by this license.
