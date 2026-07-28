---
title: "Skool + Cursor — Run Your Community from the Editor via MCP (2026)"
description: "Connect Skool to Cursor with one MCP server entry. Approve members, reply to posts, publish courses from chat — no API code. Setup, example session, gotchas."
slug: /integrations/skool-cursor
type: integration
primary_keyword: "skool cursor"
search_volume_monthly: 0
funnel: A
playbook: integrations
last_updated: 2026-05-21
canonical: https://skool-api.cristiantala.com/integrations/skool-cursor/
render_with_liquid: false
---


> **Quick reference (TL;DR for agents)**
> - **What this enables:** operate a Skool community from inside Cursor — "approve the pending members with a real LinkedIn", "post this changelog to the community feed" — in plain English while you stay in your editor.
> - **Method:** add the [Apify-hosted Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-cursor&fpr=cristian) as an **MCP server** in `~/.cursor/mcp.json` (or `.cursor/mcp.json` per project) via Apify's MCP gateway. Cursor lists every Skool action as a tool.
> - **Config:** one `mcpServers` entry running `npx @apify/actors-mcp-server --actors=cristiantala/skool-all-in-one-api`.
> - **Auth flow:** `auth:login` once → `cookies` string cached → reuse for ~3.5 days.
> - **Cost:** Apify pay-per-event (~$0.005–$0.01 per Skool action). Cursor on your existing plan.

## Why Cursor + Skool?

Skool has **no official API**. If Cursor is where you write code, the last thing you want is to alt-tab to the Skool web UI to approve a member or pin a post — context-switching out of your editor breaks flow.

Cursor speaks **MCP natively**: it reads `mcp.json`, discovers every tool an MCP server exposes, and lets the Agent call them with approval. The [Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-cursor&fpr=cristian) plugs in as one MCP server, so all 30+ Skool admin actions become tools in your chat alongside your codebase tools.

Why this is a clean fit for Cursor specifically:

1. **`mcp.json` is project-aware.** Drop the server in `.cursor/mcp.json` and the Skool tools travel with that repo — perfect if a specific project (your community's site, your bot) is where you manage Skool.
2. **The Agent already plans multi-step.** "Review the waitlist, approve verified LinkedIn, summarize the rest" is one sentence; Cursor calls `members:pending`, screens, then `members:batchApprove`.
3. **Tool approval is built in.** Cursor asks before each tool call by default — you see the exact args (`memberId`, post content) before anything writes to Skool. Flip on auto-run later for low-stakes reads.

> This page is the **MCP-native** path for Cursor. For the general MCP pattern (and other clients), see **[Skool MCP](skool-mcp.md)**. Not in an editor? **[Skool + Claude Code](skool-claude-code.md)** covers the CLI.

## Setup — add one MCP server (5 minutes)

### 1. Get your Apify API token

Sign up at [apify.com](https://apify.com?fpr=cristian) — the free tier covers most communities. Grab a token from [console.apify.com/account/integrations](https://console.apify.com/sign-up?fpr=cristian).

### 2. Add the Skool actor to `mcp.json`

Cursor reads MCP servers from two locations:

- **Project:** `.cursor/mcp.json` in the repo root — Skool tools available only in that project.
- **Global:** `~/.cursor/mcp.json` in your home directory — Skool tools everywhere.

Create or edit the file and add the Skool actor as an MCP server:

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
        "APIFY_TOKEN": "${env:APIFY_TOKEN}"
      }
    }
  }
}
```

Cursor supports config interpolation, so `${env:APIFY_TOKEN}` pulls the token from your shell environment instead of hardcoding it. Set it in your `~/.zshrc`:

```bash
export APIFY_TOKEN=apify_api_...
```

### 3. Enable and verify

Open **Settings** (`Cmd+Shift+J`) → **Features → Model Context Protocol**. The `skool` server should be listed and toggled on. The Skool actions appear under **Available Tools** in chat. Pass your Skool `cookies` and `groupSlug` as params on the first call (or fetch cookies with `auth:login` — see the example below).

> **Tip:** Use the Cursor Marketplace / [cursor.directory](https://cursor.directory) one-click install only for servers you trust. For Skool, the JSON above is the canonical, auditable setup.

## Example session — triage the waitlist without leaving your repo

You're mid-feature in Cursor and a notification reminds you the waitlist is piling up. In the Agent panel you type:

> List my pending Skool members and approve the ones with a real LinkedIn. Show me the borderline cases so I can decide.

Cursor plans and calls the tools (asking for your approval on each write):

```
1. skool_members_pending          → fetches the approval queue
2. (Agent screens each: LinkedIn reachable? survey specific?)
3. skool_members_batch_approve    → approves the clear yeses in one call
4. prints the borderline ones     → you click approve/reject inline
```

You never left the editor. The tool-confirmation dialog shows you the exact `memberId` list before the batch approval fires, so there are no surprises. End-to-end this is ~30 seconds and about a cent per approved member. Full walkthrough: [Review & batch-approve your waitlist](../recipes/review-and-batch-approve-waitlist.md).

## How it works

```
Cursor (your editor)               Apify                          Skool
────────────────────               ─────                          ─────
reads ~/.cursor/mcp.json
  → spawns @apify/actors-mcp-server (stdio)
        │  Agent picks tool + params
        ▼
[MCP tool call ──────POST JSON───→ run-sync-get-dataset-items ──→ api.skool.com]
{ action, cookies, groupSlug, ... }                              (login + WAF token +
        │                                  │                       buildId handled by actor)
        ◄──────── { success: true, data } ◄────────────────────────┘
        │
   renders result in the Agent panel
```

Every Skool operation is one MCP tool call → one HTTP POST. The actor handles Playwright login, WAF token rotation, and Skool buildId changes. Cursor just sees a clean toolset.

## What you can ask Cursor to do — full action surface

The MCP server exposes the entire Skool admin surface as tools. You ask in plain English; the Agent maps it to one of these actions. Full params for each: [Actions reference](../docs/actions.md).

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

## Cursor-specific gotchas

- **Tools default to "ask for approval".** Cursor prompts before every MCP tool call — good for writes (you confirm the `memberId` or post content), tedious for read-heavy sessions. Enable [auto-run](https://cursor.com/docs/agent/tools/terminal) only for read actions, or pre-list safe tools in `~/.cursor/permissions.json`. Keep writes manual.
- **Cookies live in params, not env.** Unlike a custom MCP server, the Apify gateway is generic — pass `cookies` and `groupSlug` as tool-call params. Have the Agent call `auth:login` once, then reuse the returned `cookies` for ~3.5 days. Re-run on `WAF_EXPIRED`.
- **Restart after editing `mcp.json`.** Cursor loads MCP servers at startup. After changing the file, toggle the server off/on in Settings → Features → Model Context Protocol, or reload the window.
- **Debug via MCP Logs.** If the `skool` server shows no tools, open the Output panel (`Cmd+Shift+U`) and select **"MCP Logs"** — npx download failures and token errors show there.
- **`x402-payment-required` on every call:** Not a billing issue — it's a stale `UNDER_MAINTENANCE` flag from Apify's heuristic. Open the [actor page](https://apify.com/cristiantala/skool-all-in-one-api?fpr=cristian) in Apify Console once to reset. Details in [error handling](../docs/error-handling.md).
- **`parentId` for comment replies:** top-level comment → `rootId == parentId == postId`. Reply to a comment → `rootId == postId`, `parentId == commentId`. Mixing these is the most common silent bug.
- **`memberId` vs `id`:** for approve/reject, pass `memberId` from `members:pending`, not the request `id`. The wrong one gives a silent 404.

## Hand this to your agent

Don't want to touch `mcp.json` yet? Paste this into Cursor's Agent (or any coding agent) and it knows the MCP setup for Skool in one shot:

```
To operate a Skool community from Cursor, add the Apify-hosted "Skool All-in-One API"
actor (cristiantala/skool-all-in-one-api) as an MCP server. Skool has no official API;
this actor is it.

Add to ~/.cursor/mcp.json (global) or .cursor/mcp.json (project):
{
  "mcpServers": {
    "skool": {
      "command": "npx",
      "args": ["-y", "@apify/actors-mcp-server", "--actors=cristiantala/skool-all-in-one-api"],
      "env": { "APIFY_TOKEN": "${env:APIFY_TOKEN}" }
    }
  }
}

Then Settings (Cmd+Shift+J) → Features → Model Context Protocol → enable "skool".
The Skool actions appear as tools. Auth: call action "auth:login" with {email,password,groupSlug}
ONCE, reuse the returned `cookies` (~3.5 day TTL); re-run on errorCode "WAF_EXPIRED".
Approve/reject use params.memberId (from members:pending), NOT id.
Comment reply: parentId = the comment id, rootId = the post id; top-level = both postId.
Full action list + params: https://skool-api.cristiantala.com/for/ai-agents/
```

For the full agent primer (function-calling specs, idempotency table, error-recovery patterns), see **[Skool for AI agents](../for/ai-agents.md)**.

## See also

- [Skool MCP](skool-mcp.md) — the general MCP pattern + the hosted gateway, shared by all MCP clients
- [Skool + Cline](skool-cline.md) — same MCP path, inside VS Code
- [Skool + Windsurf](skool-windsurf.md) — same MCP path, inside Cascade
- [Skool + Claude Code](skool-claude-code.md) — the terminal/CLI path with a drop-in Skill
- [Skool for AI agents](../for/ai-agents.md) — full pattern library + function-calling specs
- [Actions reference](../docs/actions.md) — complete list of actions and params
- [All integrations →](index.md)

---

## Plug Skool into Cursor today

[**→ Use the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-cursor&fpr=cristian)

- Pay-per-event (~$0.005–$0.01 per Skool action, ~$1.50/mo typical)
- Read AND write — full API surface (posts, comments, members, classroom, files, Auto DM)
- One `mcpServers` entry, no integration code to maintain

*No Skool community yet? [Launch one in 10 minutes](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "TechArticle",
  "headline": "Skool + Cursor — Run Your Community from the Editor via MCP",
  "description": "Connect Skool to Cursor with one MCP server entry. Approve members, reply to posts, publish courses from chat — no API code.",
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
  "mainEntityOfPage": "https://skool-api.cristiantala.com/integrations/skool-cursor/"
}
</script>
