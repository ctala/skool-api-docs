---
title: "Skool + Goose — Run Your Community as a Goose MCP Extension (2026)"
description: "Connect Skool to Block's Goose agent via an MCP extension. Add the Apify-hosted Skool actor with `goose configure` or config.yaml, then approve members, post, and publish courses by chat."
slug: /integrations/skool-goose
type: integration
primary_keyword: "skool goose"
search_volume_monthly: 0
funnel: A
playbook: integrations
last_updated: 2026-05-21
canonical: https://ctala.github.io/skool-api-docs/integrations/skool-goose/
render_with_liquid: false
---


> **Quick reference (TL;DR for agents)**
> - **What this enables:** Goose reads AND writes to Skool — approve members, post, reply, publish courses — as a native MCP **extension**, driven by chat or autonomous task.
> - **Method:** add the [Apify-hosted Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-goose) as a stdio extension via `goose configure` or `~/.config/goose/config.yaml`. Apify's MCP gateway exposes every action as a tool.
> - **Auth flow:** `auth:login` once → `cookies` string in the extension `env` → reuse for ~3.5 days.
> - **Latency:** ~2s per tool call (cookies cached) / ~10s on `auth:login` cold start.
> - **Cost:** Apify pay-per-event (~$0.005–$0.01 per Skool action). Goose on your existing LLM provider.

## Why Goose + Skool?

Skool has **no official API**. If Goose already runs your dev tasks, you don't want to drop out of it to open the Skool web UI and click through member approvals or course uploads by hand.

Goose helped shape MCP, and its **extension** system is MCP all the way down — every extension you add is an MCP server, every server's tools become callable by the agent. The [Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-goose) is hosted on Apify's MCP gateway, so adding it is the same one-step flow as any other Goose extension. No SDK, no Playwright in your runtime — Goose can drive your whole Skool admin surface.

Why Goose specifically fits well here:

1. **Extension = MCP server, no special casing.** Skool is just another stdio extension alongside your developer/computercontroller extensions.
2. **Interactive `goose configure` wizard.** Add the extension by answering prompts — name, command, timeout, env vars — no hand-edited JSON if you don't want it.
3. **Autonomous task runs.** Goose is built to run multi-step tasks unattended; "every morning, approve verified applicants and post the digest" is a natural Goose recipe once the Skool extension is wired.

## Setup — add the Skool extension (5 minutes)

### 1. Get your Apify API token

Sign up at [apify.com](https://apify.com) — the free tier covers most communities. Grab a token from [console.apify.com/account/integrations](https://console.apify.com/account/integrations).

### 2. Get your Skool cookies (one-time, valid ~3.5 days)

Run this once and keep the returned `cookies` string — you'll store it in the extension `env`:

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

### 3. Add the extension

**Option A — interactive (`goose configure`):**

```bash
goose configure
# → Add Extension
# → Command-line Extension (STDIO)
#   Name:    skool
#   Command: npx -y @apify/actors-mcp-server --token=YOUR_APIFY_TOKEN --actors=cristiantala/skool-all-in-one-api
#   Timeout: 60   (seconds — auth:login needs headroom)
#   Env:     SKOOL_COOKIES=...   SKOOL_GROUP_SLUG=your-community-slug
```

**Option B — edit `~/.config/goose/config.yaml` directly** (on Windows: `%APPDATA%\Block\goose\config\config.yaml`). Add a `skool` entry under `extensions`:

```yaml
extensions:
  skool:
    type: stdio
    command: npx
    args:
      - "-y"
      - "@apify/actors-mcp-server"
      - "--token=YOUR_APIFY_TOKEN"
      - "--actors=cristiantala/skool-all-in-one-api"
    env:
      SKOOL_COOKIES: "the-cookies-string-from-step-2"
      SKOOL_GROUP_SLUG: "your-community-slug"
    timeout: 300
```

### 4. Start a session and verify

```bash
goose session
```

The Skool actions are now available as tools. You can also load it for a single run without persisting config:

```bash
goose session --with-extension "npx -y @apify/actors-mcp-server --token=YOUR_APIFY_TOKEN --actors=cristiantala/skool-all-in-one-api"
```

## How the connection works

```
Goose                              Apify                          Skool
─────                              ─────                          ─────
reads ~/.config/goose/config.yaml  →  starts @apify/actors-mcp-server (extension)
        │  picks a tool + structured params
        ▼
[MCP call ───────────→ run-sync-get-dataset-items ──────────────→ api.skool.com]
{ action, cookies, groupSlug, ... }                              (login + WAF token +
        │                                  │                       buildId handled by actor)
        ◄──────── { success: true, data } ◄────────────────────────┘
        │
   Goose reports back / continues the task
```

Every Skool operation = one MCP tool call backed by one HTTP POST. The actor handles Playwright login, WAF token rotation, and Skool buildId changes for you.

## Example session — clear the waitlist by chat

You start `goose session` and type:

> List my pending Skool members and approve the ones with a real LinkedIn. Show me the rest so I can decide.

Goose calls, in sequence:

```
1. members:pending                    → fetches the approval queue
2. (reasons over each: LinkedIn reachable? survey specific? channel?)
3. members:batchApprove               → approves the clear yeses in one call
4. prints the borderline ones for you → you decide the edge cases
```

End-to-end this replaces ~10 minutes of clicking through the Skool admin UI, at about a cent per approved member. Full walkthrough: [Review & batch-approve your waitlist](../recipes/review-and-batch-approve-waitlist.md).

## What you can ask Goose to do — full action surface

The actor exposes the entire Skool admin surface as MCP tools. You ask in plain English; Goose maps it to one of these actions. Full params for each: [Actions reference](../docs/actions.md).

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
| `posts:getComments` / `posts:getCommentsFull` | Read a post's comment tree (fast / full-scroll, no cap) |

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

- **`x402-payment-required` on every call:** Not a billing issue — it's a stale `UNDER_MAINTENANCE` flag from Apify's heuristic. Open the [actor page](https://apify.com/cristiantala/skool-all-in-one-api) in Apify Console once to reset. Details in [error handling](../docs/error-handling.md).
- **Cookies expiring silently:** When a call returns `errorCode: "WAF_EXPIRED"`, re-run `auth:login` and update `SKOOL_COOKIES` in `config.yaml`, then restart the session. The `hint` field tells Goose exactly this.
- **`parentId` for comment replies:** top-level comment → `rootId == parentId == postId`. Reply to a comment → `rootId == postId`, `parentId == commentId`. Mixing these is the most common silent bug.
- **`memberId` vs `id`:** for approve/reject, pass `memberId` from `members:pending`, not the `id`. The wrong one gives a silent 404.
- **Extension `timeout` too low for `auth:login`:** Goose's per-tool timeout (the wizard's "Timeout in seconds") must be ≥30s because `auth:login` runs a real browser login (~10s). The example uses `300`.
- **Goose may need tool resources, not just tools:** if your Goose build only surfaces MCP *resources* and not tool calls, update Goose — the actor exposes actions as MCP tools, which current Goose invokes directly.

## Hand this to your agent

Don't want to run the extension? Paste this primer into a Goose session (or any agent) and it knows how to drive Skool over plain HTTP in one shot:

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

Full action list + params: https://ctala.github.io/skool-api-docs/docs/actions/
```

The full pattern library (function-calling specs, idempotency table, the LLM-readable `hint` contract) lives in [Skool for AI agents](../for/ai-agents.md).

## See also

- [Skool MCP](skool-mcp.md) — the general MCP pattern (Claude Desktop, Cursor, Cline) this page builds on
- [Skool + Gemini CLI](skool-gemini-cli.md) — the same MCP approach for Google's Gemini CLI
- [Skool + Claude](skool-claude.md) — Anthropic API + Claude Desktop
- [Skool for AI agents](../for/ai-agents.md) — full pattern library + function-calling specs
- [Recipe: Use the Skool API as an MCP tool](../recipes/use-skool-api-as-mcp-tool.md)
- [All integrations →](index.md)

---

## Plug Skool into Goose today

[**→ Use the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-goose)

- Pay-per-event (~$0.005–$0.01 per Skool action, ~$1.50/mo typical)
- Read AND write — full API surface (posts, comments, members, classroom, files, Auto DM)
- Native MCP extension — one `goose configure` step, no integration code to maintain

*No Skool community yet? [Launch one in 10 minutes](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "TechArticle",
  "headline": "Skool + Goose — Run Your Community as a Goose MCP Extension",
  "description": "Connect Skool to Block's Goose agent via an MCP extension. Add the Apify-hosted Skool actor with goose configure or config.yaml, then approve members, post, and publish courses by chat.",
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
  "mainEntityOfPage": "https://ctala.github.io/skool-api-docs/integrations/skool-goose/"
}
</script>
