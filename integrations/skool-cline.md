---
title: "Skool + Cline — Manage Your Community in VS Code via MCP (2026)"
description: "Connect Skool to Cline with one MCP server entry. Approve members, reply to posts, publish courses from the Cline panel — no API code. Setup, example, gotchas."
slug: /integrations/skool-cline
type: integration
primary_keyword: "skool cline"
search_volume_monthly: 0
funnel: A
playbook: integrations
last_updated: 2026-05-21
canonical: https://ctala.github.io/skool-api-docs/integrations/skool-cline/
render_with_liquid: false
---


> **Quick reference (TL;DR for agents)**
> - **What this enables:** run a Skool community from the Cline panel in VS Code — "reply to every unanswered post from the last 7 days", "approve the verified applicants" — in plain English, without leaving your IDE.
> - **Method:** add the [Apify-hosted Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-cline) as an **MCP server** in Cline's MCP settings (or `~/.cline/mcp.json` for the CLI) via Apify's MCP gateway.
> - **Config:** one `mcpServers` entry running `npx @apify/actors-mcp-server --actors=cristiantala/skool-all-in-one-api`, with `autoApprove` to scope which tools run unattended.
> - **Auth flow:** `auth:login` once → `cookies` string cached → reuse for ~3.5 days.
> - **Cost:** Apify pay-per-event (~$0.005–$0.01 per Skool action). Cline + your own model key.

## Why Cline + Skool?

Skool has **no official API**. Cline is the community-favorite open-source agent for VS Code, and it ships some of the deepest native MCP support of any client — a marketplace, a per-server `autoApprove` allowlist, restartable servers, and a CLI wizard. If you already install MCP servers for GitHub, Postgres, or browser tools, adding Skool is the same two-minute motion.

The [Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-cline) wraps the entire Skool admin surface in one HTTP endpoint. Exposed through Cline's MCP layer, every Skool action becomes a tool Cline can call right next to your code tools.

Why Cline is a strong fit specifically:

1. **`autoApprove` per tool.** Cline lets you allowlist exactly which tools run without a confirmation. Put `members:pending`, `posts:list`, and other reads on `autoApprove`; keep `members:ban` and `posts:delete` gated behind a manual click.
2. **It's already a coding agent that loops.** "Reply to every unanswered post" becomes a plan: `posts:filter` (unanswered) → draft → `posts:createComment` per thread, with you approving the drafts.
3. **CLI + IDE share definitions.** Configure once with the `cline mcp` wizard or `~/.cline/mcp.json` and the same Skool server works whether you're in VS Code or the terminal.

> This is the **MCP-native** path for Cline. For the general MCP pattern shared across clients, see **[Skool MCP](skool-mcp.md)**.

## Setup — add the MCP server (5 minutes)

### 1. Get your Apify API token

Sign up at [apify.com](https://apify.com) — the free tier covers most communities. Token from [console.apify.com/account/integrations](https://console.apify.com/account/integrations).

### 2. Open Cline's MCP settings

In the **Cline panel**, click the **MCP Servers** icon (the stacked-server icon in the top toolbar) → **Configure** tab → **Configure MCP Servers**. This opens the MCP settings JSON. (Using the Cline CLI instead? Edit `~/.cline/mcp.json`, or run `cline mcp` for the interactive wizard.)

### 3. Add the Skool actor

Add the actor under `mcpServers`:

```json
{
  "mcpServers": {
    "skool": {
      "command": "npx",
      "args": [
        "-y",
        "@apify/actors-mcp-server",
        "--actors=cristiantala/skool-all-in-one-api"
      ],
      "env": {
        "APIFY_TOKEN": "apify_api_..."
      },
      "disabled": false,
      "autoApprove": ["members:pending", "posts:list", "posts:filter", "classroom:listCourses"]
    }
  }
}
```

The `autoApprove` array is the Cline-specific safety lever: list only read actions you trust to run silently. Every write (`posts:create`, `members:approve`, anything destructive) stays behind a manual approval click. Save the file — Cline picks up the new server and the Skool tools appear in the panel.

## Example session — sweep unanswered posts in VS Code

You're working in a repo and want to clear the community backlog without context-switching. In the Cline panel you type:

> Find every post in my Skool community from the last 7 days with no reply, draft a short helpful comment for each, show me the drafts, then post the ones I approve.

Cline plans and executes (reads auto-run, writes wait for you):

```
1. skool_posts_filter { unanswered: true, since: "<7d ago>" }   → auto-approved (read)
2. (Cline drafts a comment per thread, shows them inline)
3. you approve 4 of 6 drafts
4. skool_posts_create_comment × 4                                → each waits for your click
```

Because comment replies are non-idempotent, Cline posts each approved draft exactly once, and the per-call confirmation means you never accidentally double-post. Reads were silent thanks to `autoApprove`; the writes were deliberate. Full pattern: [Reply to unanswered posts](../recipes/reply-unanswered-posts.md).

## How it works

```
Cline (VS Code panel)              Apify                          Skool
─────────────────────              ─────                          ─────
reads MCP settings JSON
  → spawns @apify/actors-mcp-server (stdio)
        │  Cline picks tool + params (autoApprove gates writes)
        ▼
[MCP tool call ──────POST JSON───→ run-sync-get-dataset-items ──→ api.skool.com]
{ action, cookies, groupSlug, ... }                              (login + WAF token +
        │                                  │                       buildId handled by actor)
        ◄──────── { success: true, data } ◄────────────────────────┘
        │
   renders result in the Cline panel
```

Every Skool operation is one MCP tool call → one HTTP POST. The actor handles Playwright login, WAF rotation, and buildId changes — Cline just sees a clean toolset.

## What you can ask Cline to do — full action surface

The MCP server exposes the entire Skool admin surface as tools. You ask in plain English; Cline maps it to one of these actions. Full params for each: [Actions reference](../docs/actions.md).

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
| `classroom:deleteUnit` | Delete a course / folder / page (destructive — confirms first) |

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

## Cline-specific gotchas

- **Scope `autoApprove` to reads only.** It's tempting to auto-approve everything to stop the confirmation prompts — don't. Keep `members:approve`, `posts:create`, `posts:createComment`, and all destructive actions off the allowlist so a misread instruction can't mass-write to your community.
- **Raise the request timeout for `auth:login`.** Cline lets you set a per-server request timeout in MCP settings. A cold `auth:login` runs a Playwright login (~10s); bump the timeout to ≥30s so it doesn't fail spuriously.
- **Restart the server after editing JSON.** Use the **Restart** control on the server in MCP settings if tools don't refresh after you change the config — Cline won't always hot-reload.
- **Cookies are params, not env.** The Apify gateway is a generic actor wrapper — pass `cookies` and `groupSlug` as tool-call params. Run `auth:login` once, reuse the `cookies` (~3.5 days), re-run on `WAF_EXPIRED`.
- **`x402-payment-required` on every call:** Not a billing issue — it's a stale `UNDER_MAINTENANCE` flag from Apify's heuristic. Open the [actor page](https://apify.com/cristiantala/skool-all-in-one-api) in Apify Console once to reset. Details in [error handling](../docs/error-handling.md).
- **`parentId` for comment replies:** top-level comment → `rootId == parentId == postId`. Reply to a comment → `rootId == postId`, `parentId == commentId`. Mixing these is the most common silent bug.
- **`memberId` vs `id`:** for approve/reject, pass `memberId` from `members:pending`, not the request `id`. The wrong one gives a silent 404.

## Hand this to your agent

Don't want to open the MCP settings yet? Paste this into Cline and it knows the setup for Skool:

```
To operate a Skool community from Cline, add the Apify-hosted "Skool All-in-One API"
actor (cristiantala/skool-all-in-one-api) as an MCP server. Skool has no official API;
this actor is it.

In Cline: MCP Servers icon → Configure tab → Configure MCP Servers, then add under mcpServers
(CLI users: ~/.cline/mcp.json):
{
  "mcpServers": {
    "skool": {
      "command": "npx",
      "args": ["-y", "@apify/actors-mcp-server", "--actors=cristiantala/skool-all-in-one-api"],
      "env": { "APIFY_TOKEN": "apify_api_..." },
      "disabled": false,
      "autoApprove": ["members:pending", "posts:list", "posts:filter"]
    }
  }
}

Keep all WRITE actions OFF autoApprove. Auth: call action "auth:login" with
{email,password,groupSlug} ONCE, reuse the returned `cookies` (~3.5 day TTL);
re-run on errorCode "WAF_EXPIRED". Approve/reject use params.memberId (from
members:pending), NOT id. Comment reply: parentId = comment id, rootId = post id;
top-level = both postId.
Full action list + params: https://ctala.github.io/skool-api-docs/for/ai-agents/
```

For the full agent primer (function-calling specs, idempotency table, error-recovery patterns), see **[Skool for AI agents](../for/ai-agents.md)**.

## See also

- [Skool MCP](skool-mcp.md) — the general MCP pattern + the hosted gateway, shared by all MCP clients
- [Skool + Cursor](skool-cursor.md) — same MCP path, inside the Cursor editor
- [Skool + Windsurf](skool-windsurf.md) — same MCP path, inside Cascade
- [Skool + Claude Code](skool-claude-code.md) — the terminal/CLI path with a drop-in Skill
- [Skool for AI agents](../for/ai-agents.md) — full pattern library + function-calling specs
- [Actions reference](../docs/actions.md) — complete list of actions and params
- [All integrations →](index.md)

---

## Plug Skool into Cline today

[**→ Use the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-cline)

- Pay-per-event (~$0.005–$0.01 per Skool action, ~$1.50/mo typical)
- Read AND write — full API surface (posts, comments, members, classroom, files, Auto DM)
- One `mcpServers` entry + `autoApprove` to control unattended writes

*No Skool community yet? [Launch one in 10 minutes](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "TechArticle",
  "headline": "Skool + Cline — Manage Your Community in VS Code via MCP",
  "description": "Connect Skool to Cline with one MCP server entry. Approve members, reply to posts, publish courses from the Cline panel — no API code.",
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
  "mainEntityOfPage": "https://ctala.github.io/skool-api-docs/integrations/skool-cline/"
}
</script>
