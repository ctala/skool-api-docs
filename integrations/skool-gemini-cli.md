---
title: "Skool + Gemini CLI — Run Your Community as MCP Tools (2026)"
description: "Connect Skool to Gemini CLI via MCP. Add the Apify-hosted Skool actor to your ~/.gemini/settings.json or with `gemini mcp add`, then approve members, post, and publish courses in natural language."
slug: /integrations/skool-gemini-cli
type: integration
primary_keyword: "skool gemini cli"
search_volume_monthly: 0
funnel: A
playbook: integrations
last_updated: 2026-05-21
canonical: https://skool-api.cristiantala.com/integrations/skool-gemini-cli/
render_with_liquid: false
---


> **Quick reference (TL;DR for agents)**
> - **What this enables:** Gemini CLI reads AND writes to Skool — approve members, post, reply, publish courses — as native MCP tools, in plain English from your terminal.
> - **Method:** add the [Apify-hosted Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-gemini-cli&fpr=cristian) as an MCP server in `~/.gemini/settings.json` (or run `gemini mcp add`). Apify's MCP gateway exposes every actor action as a tool.
> - **Auth flow:** `auth:login` once → `cookies` string in the MCP server `env` → reuse for ~3.5 days.
> - **Latency:** ~2s per tool call (cookies cached) / ~10s on `auth:login` cold start.
> - **Cost:** Apify pay-per-event (~$0.005–$0.01 per Skool action). Gemini CLI on your existing Google AI plan.

## Why Gemini CLI + Skool?

Skool has **no official API**. If you run your community from Gemini CLI, you don't want to break flow, open the Skool web UI, and click through member approvals or course uploads by hand.

Gemini CLI speaks **MCP (Model Context Protocol) natively** — point it at an MCP server in `settings.json` and every tool that server exposes becomes callable in conversation. The [Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-gemini-cli&fpr=cristian) is hosted on Apify's MCP gateway, so it plugs straight in. No SDK, no Playwright in your runtime, no glue code — one config block and Gemini CLI can drive your whole Skool admin surface.

Why Gemini CLI specifically fits well here:

1. **Native MCP discovery.** Gemini CLI lists the actor's tools at startup; you don't hand-write a function schema for each action.
2. **Two ways to wire it.** Edit `~/.gemini/settings.json` by hand, or run `gemini mcp add` for a guided add — pick whichever fits your workflow.
3. **Google-scale context window.** Long course trees and big member lists fit comfortably, so "summarize the last 50 posts and reply to the unanswered ones" is one prompt.

## Setup — add the MCP server (5 minutes)

### 1. Get your Apify API token

Sign up at [apify.com](https://apify.com?fpr=cristian) — the free tier covers most communities. Grab a token from [console.apify.com/account/integrations](https://console.apify.com/sign-up?fpr=cristian).

### 2. Get your Skool cookies (one-time, valid ~3.5 days)

Run this once and keep the returned `cookies` string — you'll paste it into the MCP server `env`:

```bash
curl -X POST \
  "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=YOUR_APIFY_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "action": "auth:login",
    "email": "admin@yourcommunity.com",
    "password": "your-skool-password",
    "groupSlug": "your-community-slug"
  }'
```

### 3. Add the Skool MCP server

**Option A — edit `~/.gemini/settings.json`** (global) or `.gemini/settings.json` (project). Add a `skool` entry under `mcpServers`:

```json
{
  "mcpServers": {
    "skool": {
      "command": "npx",
      "args": [
        "-y",
        "@apify/actors-mcp-server",
        "--token=YOUR_APIFY_TOKEN",
        "--actors=cristiantala/skool-all-in-one-api"
      ],
      "env": {
        "SKOOL_COOKIES": "the-cookies-string-from-step-2",
        "SKOOL_GROUP_SLUG": "your-community-slug"
      },
      "timeout": 60000
    }
  }
}
```

**Option B — use the CLI helper:**

```bash
gemini mcp add skool \
  npx -y @apify/actors-mcp-server \
  --token=YOUR_APIFY_TOKEN \
  --actors=cristiantala/skool-all-in-one-api
```

Bump the `timeout` to at least `60000` (60s) — `auth:login` is a real browser login and the default tool-call timeout can cut it off.

### 4. Restart and verify

Restart Gemini CLI. The Skool actions show up as tools — ask `/mcp` (or list tools) to confirm `skool` is connected.

## How the connection works

```
Gemini CLI                         Apify                          Skool
──────────                         ─────                          ─────
reads ~/.gemini/settings.json  →  starts @apify/actors-mcp-server
        │  picks a tool + structured params
        ▼
[MCP call ───────────→ run-sync-get-dataset-items ──────────────→ api.skool.com]
{ action, cookies, groupSlug, ... }                              (login + WAF token +
        │                                  │                       buildId handled by actor)
        ◄──────── { success: true, data } ◄────────────────────────┘
        │
   Gemini reports back in plain English
```

Every Skool operation = one MCP tool call backed by one HTTP POST. The actor handles Playwright login, WAF token rotation, and Skool buildId changes for you.

## Example session — clear the waitlist from the terminal

You're in a Gemini CLI session and type:

> List my pending Skool members and approve the ones with a real LinkedIn. Show me the rest so I can decide.

Gemini CLI calls, in sequence:

```
1. members:pending                    → fetches the approval queue
2. (reasons over each: LinkedIn reachable? survey specific? channel?)
3. members:batchApprove               → approves the clear yeses in one call
4. prints the borderline ones for you → you decide the edge cases
```

End-to-end this replaces ~10 minutes of clicking through the Skool admin UI, at about a cent per approved member. Full walkthrough: [Review & batch-approve your waitlist](../recipes/review-and-batch-approve-waitlist.md).

## What you can ask Gemini CLI to do — full action surface

The actor exposes the entire Skool admin surface as MCP tools. You ask in plain English; Gemini CLI maps it to one of these actions. Full params for each: [Actions reference](../docs/actions.md).

**Posts & comments**

| Action | What it does |
|---|---|
| `posts:list` / `posts:filter` | List or filter posts (by date, label, unanswered) |
| `posts:get` | Fetch a single post |
| `posts:create` | Publish a post (plain text + optional label/video) |
| `posts:update` / `posts:delete` | Edit or delete a post/comment |
| `posts:createComment` | Comment on a post or reply to a comment |
| `posts:pin` / `posts:unpin` | Pin or unpin a post |
| `posts:vote` | Upvote / clear vote |
| `posts:getComments` / `posts:getCommentsFull` | Read a post's comment tree (one page / entire thread, no cap) |

**Members**

| Action | What it does |
|---|---|
| `members:list` | List active members |
| `members:pending` | List the approval queue |
| `members:approve` / `members:reject` | Approve or reject one applicant |
| `members:batchApprove` | Approve N applicants in one run |
| `members:ban` | Ban a member (destructive — confirm first) |

**Events**

| Action | What it does |
|---|---|
| `events:list` / `events:upcoming` | List calendar events (all / future only) |

**Classroom (courses)**

| Action | What it does |
|---|---|
| `classroom:listCourses` / `classroom:getTree` | List courses / read a course's full tree |
| `classroom:createCourse` / `createFolder` / `createPage` | Build course structure |
| `classroom:setBody` | Set a lesson's content (markdown → auto-converted to TipTap) |
| `classroom:updateCourse` | Edit course settings — cover, tier, privacy (read-then-write) |
| `classroom:updateResources` | Attach / detach downloadable files on a lesson |
| `classroom:deleteUnit` | Delete a course / folder / page (destructive — confirm first) |

**Files & groups**

| Action | What it does |
|---|---|
| `files:uploadImage` / `files:uploadFile` | Upload a cover image / a private attachment |
| `groups:get` | Read group metadata (incl. post categories) |
| `groups:setAutoDM` | Set the welcome DM new members receive |

**System**

| Action | What it does |
|---|---|
| `system:health` / `system:debug` | Healthcheck / SSR diagnostics |
| `auth:login` | Get fresh cookies (~3.5 day TTL) |

## Production gotchas

- **`x402-payment-required` on every call:** Not a billing issue — it's a stale `UNDER_MAINTENANCE` flag from Apify's heuristic. Open the [actor page](https://apify.com/cristiantala/skool-all-in-one-api?fpr=cristian) in Apify Console once to reset. Details in [error handling](../docs/error-handling.md).
- **Cookies expiring silently:** When a call returns `errorCode: "WAF_EXPIRED"`, re-run `auth:login` and update `SKOOL_COOKIES` in `settings.json`, then restart the session. The `hint` field tells Gemini exactly this.
- **`parentId` for comment replies:** top-level comment → `rootId == parentId == postId`. Reply to a comment → `rootId == postId`, `parentId == commentId`. Mixing these is the most common silent bug.
- **`memberId` vs `id`:** for approve/reject, pass `memberId` from `members:pending`, not the `id`. The wrong one gives a silent 404.
- **Tool-call timeout cuts off `auth:login`:** Gemini CLI's default MCP timeout is short; `auth:login` runs a real browser login (~10s). Set `"timeout": 60000` on the `skool` server entry.
- **Trust prompt on first run:** Gemini CLI asks to confirm tool execution from a new MCP server. Approve `skool` once, or set it as trusted in the `mcp.allowed` list so unattended runs don't stall.

## Hand this to your agent

Don't want to run the hosted MCP server? Paste this primer into Gemini CLI (or any agent) and it knows how to drive Skool over plain HTTP in one shot:

```
You can operate a Skool community through the Apify-hosted "Skool All-in-One API"
actor (cristiantala/skool-all-in-one-api). Skool has no official API; this actor is it.

Every action is ONE HTTP POST:
  POST https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=$APIFY_TOKEN&build=latest&timeout=90
  body: { "action": "<namespace>:<op>", "cookies": "$SKOOL_COOKIES",
          "groupSlug": "<your-slug>", "params": { ...per action... } }

Auth: call "auth:login" with {email,password,groupSlug} ONCE, save the returned
  `cookies` string, reuse it (~3.5 day TTL). On errorCode "WAF_EXPIRED", re-run auth:login.

Rules: members approve/reject use params.memberId (NOT id). Comment reply: parentId =
  comment id, rootId = post id. Posts are plain text. ~25 writes/min hard limit (actor
  queues — no retry loop). Every response is { success, data } or { success:false,
  errorCode, hint } — read `hint` to recover.

Full action list + params: https://skool-api.cristiantala.com/docs/actions/
```

The full pattern library (function-calling specs, idempotency table, the LLM-readable `hint` contract) lives in [Skool for AI agents](../for/ai-agents.md).

## See also

- [Skool MCP](skool-mcp.md) — the general MCP pattern (Claude Desktop, Cursor, Cline) this page builds on
- [Skool + Goose](skool-goose.md) — the same MCP approach for Block's Goose agent
- [Skool + GPT](skool-gpt.md) — OpenAI function-calling path
- [Skool + Claude](skool-claude.md) — Anthropic API + Claude Desktop
- [Skool for AI agents](../for/ai-agents.md) — full pattern library + function-calling specs
- [Recipe: Use the Skool API as an MCP tool](../recipes/use-skool-api-as-mcp-tool.md)
- [All integrations →](index.md)

---

## Plug Skool into Gemini CLI today

[**→ Use the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-gemini-cli&fpr=cristian)

- Pay-per-event (~$0.005–$0.01 per Skool action, ~$1.50/mo typical)
- Read AND write — full API surface (posts, comments, members, classroom, files, Auto DM)
- Native MCP — one config block, no integration code to maintain

*No Skool community yet? [Launch one in 10 minutes](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "TechArticle",
  "headline": "Skool + Gemini CLI — Run Your Community as MCP Tools",
  "description": "Connect Skool to Gemini CLI via MCP. Add the Apify-hosted Skool actor to your settings.json or with gemini mcp add, then approve members, post, and publish courses in natural language.",
  "datePublished": "2026-05-21",
  "dateModified": "2026-05-21",
  "author": {
    "@type": "Person",
    "name": "Cristian Tala",
    "url": "https://cristiantala.com"
  },
  "publisher": {
    "@type": "Person",
    "name": "Cristian Tala",
    "url": "https://cristiantala.com"
  },
  "mainEntityOfPage": "https://skool-api.cristiantala.com/integrations/skool-gemini-cli/"
}
</script>
