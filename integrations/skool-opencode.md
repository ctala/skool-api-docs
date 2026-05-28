---
title: "Skool + OpenCode — Run Your Community from the Terminal via MCP (2026)"
description: "Connect Skool to OpenCode with one MCP entry in opencode.json. Approve members, reply to posts, publish courses from the terminal — no API code. Setup, gotchas."
slug: /integrations/skool-opencode
type: integration
primary_keyword: "skool opencode"
search_volume_monthly: 0
funnel: A
playbook: integrations
last_updated: 2026-05-21
canonical: https://skool-api.cristiantala.com/integrations/skool-opencode/
render_with_liquid: false
---


> **Quick reference (TL;DR for agents)**
> - **What this enables:** run a Skool community from OpenCode, the open-source terminal agent — "approve the verified applicants", "post the weekly digest" — in plain English, no editor required.
> - **Method:** add the [Apify-hosted Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-opencode&fpr=cristian) as an **MCP server** under the `mcp` key in `opencode.json` via Apify's MCP gateway.
> - **Config:** one `mcp` entry with `"type": "local"` running `npx @apify/actors-mcp-server --actors=cristiantala/skool-all-in-one-api`. Note: OpenCode uses a `command` **array** and `environment` (not `env`).
> - **Auth flow:** `auth:login` once → `cookies` string cached → reuse for ~3.5 days.
> - **Cost:** Apify pay-per-event (~$0.005–$0.01 per Skool action). OpenCode is free/OSS + your model key.

## Why OpenCode + Skool?

Skool has **no official API**. OpenCode is the fast-growing open-source terminal agent — provider-agnostic, runs anywhere you have a shell, and has clean MCP support baked into a single config file. If you live in the terminal and OpenCode is your agent, you want to manage your community without spawning a browser.

The [Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-opencode&fpr=cristian) wraps the entire Skool admin surface in one HTTP endpoint. Declared as one MCP server in `opencode.json`, every Skool action becomes a tool OpenCode can call from the prompt.

Why OpenCode is a good fit specifically:

1. **One config file, version-controllable.** OpenCode's `opencode.json` (with a `$schema` for autocomplete) lives in your project or `~/.config/opencode/`. The Skool server is just a few lines you can commit and share with collaborators.
2. **Provider-agnostic agent loop.** OpenCode works with any model you point it at; the Skool tools behave identically whether you run Claude, GPT, or a local model behind it.
3. **Tool-level enable/disable with globs.** OpenCode's `tools` block lets you disable Skool tools globally and re-enable them per agent — useful if you want a dedicated "community manager" agent that has Skool tools and your coding agent that doesn't.

> This is the **MCP-native** path for OpenCode. For the general MCP pattern shared across clients, see **[Skool MCP](skool-mcp.md)**. Prefer a drop-in Skill in another terminal agent? See **[Skool + Claude Code](skool-claude-code.md)**.

## Setup — add the MCP server (5 minutes)

### 1. Get your Apify API token

Sign up at [apify.com](https://apify.com?fpr=cristian) — the free tier covers most communities. Token from [console.apify.com/account/integrations](https://console.apify.com/account/integrations?fpr=cristian).

### 2. Declare the Skool server in `opencode.json`

OpenCode reads MCP servers from the `mcp` key in `opencode.json` (project root) or your global `~/.config/opencode/opencode.json`. Unlike most clients, OpenCode uses `"type": "local"`, a `command` **array**, and an `environment` object (not `env`):

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "skool": {
      "type": "local",
      "command": ["npx", "-y", "@apify/actors-mcp-server", "--actors=cristiantala/skool-all-in-one-api"],
      "environment": {
        "APIFY_TOKEN": "apify_api_..."
      },
      "enabled": true,
      "timeout": 90000
    }
  }
}
```

The `timeout` field is important here — see the gotchas below.

### 3. Verify

Start OpenCode in that directory. The Skool actions register as tools, prefixed with the server name (`skool_*`). Reference them in a prompt like `use the skool tools to list pending members`. To confirm the server connected, run `opencode mcp list`.

## Example session — post the weekly digest from the terminal

It's Monday and you want to drop a community update without leaving your shell. You run OpenCode and type:

> Use the skool tools: count active members and new posts from the last 7 days, then publish a short "weekly pulse" post to the community feed summarizing the activity.

OpenCode plans and executes:

```
1. skool_members_list                       → current member count
2. skool_posts_filter { since: "<7d ago>" } → new posts this week
3. (OpenCode drafts a short plain-text summary, shows it to you)
4. skool_posts_create { title, content }    → publishes once you confirm
```

Because `posts:create` is non-idempotent, OpenCode posts exactly once — there's no retry loop that risks a double post. The whole thing is one prompt and costs a few cents in Apify events. Pair it with OpenCode's scheduling or a cron wrapper and you have an unattended weekly digest. Related task: [Mirror a newsletter to your community](../recipes/newsletter-to-skool-post.md).

## How it works

```
OpenCode (your terminal)           Apify                          Skool
────────────────────────           ─────                          ─────
reads opencode.json (mcp key)
  → spawns @apify/actors-mcp-server (local/stdio)
        │  agent picks tool + params
        ▼
[MCP tool call ──────POST JSON───→ run-sync-get-dataset-items ──→ api.skool.com]
{ action, cookies, groupSlug, ... }                              (login + WAF token +
        │                                  │                       buildId handled by actor)
        ◄──────── { success: true, data } ◄────────────────────────┘
        │
   reports back in the terminal
```

Every Skool operation is one MCP tool call → one HTTP POST. The actor handles Playwright login, WAF rotation, and buildId changes — OpenCode just sees a clean toolset.

## What you can ask OpenCode to do — full action surface

The MCP server exposes the entire Skool admin surface as tools. You ask in plain English; OpenCode maps it to one of these actions. Full params for each: [Actions reference](../docs/actions.md).

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

## OpenCode-specific gotchas

- **Raise `timeout` — the default is 5000ms.** OpenCode defaults to a 5-second timeout for fetching tools from an MCP server. The first `auth:login` runs a Playwright login (~10s) and `npx` may also cold-download the gateway package. Set `"timeout": 90000` on the server (as in the config above) or the server will fail to register on slow starts.
- **It's `command` array + `environment`, not `command` string + `env`.** OpenCode's schema differs from Cursor/Cline/Windsurf: `command` is an **array** of strings and the env block is named `environment`. Copying a Cursor snippet verbatim will silently fail to start.
- **Watch your context budget.** OpenCode's docs explicitly warn that MCP tools add to the context window. The Skool actor surfaces ~25 actions — fine alone, but if you stack several token-heavy MCP servers, disable unused Skool tools with a glob (`"tools": { "skool*": false }`) and re-enable per agent.
- **Cookies are tool-call params.** The Apify gateway is a generic actor wrapper — pass `cookies` and `groupSlug` as params on each call. Run `auth:login` once, reuse the `cookies` (~3.5 days), re-run on `WAF_EXPIRED`.
- **`x402-payment-required` on every call:** Not a billing issue — it's a stale `UNDER_MAINTENANCE` flag from Apify's heuristic. Open the [actor page](https://apify.com/cristiantala/skool-all-in-one-api?fpr=cristian) in Apify Console once to reset. Details in [error handling](../docs/error-handling.md).
- **`parentId` for comment replies:** top-level comment → `rootId == parentId == postId`. Reply to a comment → `rootId == postId`, `parentId == commentId`. Mixing these is the most common silent bug.
- **`memberId` vs `id`:** for approve/reject, pass `memberId` from `members:pending`, not the request `id`. The wrong one gives a silent 404.

## Hand this to your agent

Don't want to edit `opencode.json` by hand? Paste this into OpenCode and it knows the setup for Skool:

```
To operate a Skool community from OpenCode, add the Apify-hosted "Skool All-in-One API"
actor (cristiantala/skool-all-in-one-api) as an MCP server. Skool has no official API;
this actor is it.

Add to opencode.json under the "mcp" key (note: command is an ARRAY, env block is
"environment", and raise timeout because auth:login takes ~10s):
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "skool": {
      "type": "local",
      "command": ["npx", "-y", "@apify/actors-mcp-server", "--actors=cristiantala/skool-all-in-one-api"],
      "environment": { "APIFY_TOKEN": "apify_api_..." },
      "enabled": true,
      "timeout": 90000
    }
  }
}

Verify with `opencode mcp list`. Auth: call action "auth:login" with {email,password,groupSlug}
ONCE, reuse the returned `cookies` (~3.5 day TTL); re-run on errorCode "WAF_EXPIRED".
Approve/reject use params.memberId (from members:pending), NOT id.
Comment reply: parentId = comment id, rootId = post id; top-level = both postId.
Full action list + params: https://skool-api.cristiantala.com/for/ai-agents/
```

For the full agent primer (function-calling specs, idempotency table, error-recovery patterns), see **[Skool for AI agents](../for/ai-agents.md)**.

## See also

- [Skool MCP](skool-mcp.md) — the general MCP pattern + the hosted gateway, shared by all MCP clients
- [Skool + Claude Code](skool-claude-code.md) — the terminal/CLI path with a drop-in Skill
- [Skool + Cursor](skool-cursor.md) — same MCP path, inside the Cursor editor
- [Skool + Cline](skool-cline.md) — same MCP path, inside VS Code
- [Skool for AI agents](../for/ai-agents.md) — full pattern library + function-calling specs
- [Actions reference](../docs/actions.md) — complete list of actions and params
- [All integrations →](index.md)

---

## Plug Skool into OpenCode today

[**→ Use the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-opencode&fpr=cristian)

- Pay-per-event (~$0.005–$0.01 per Skool action, ~$1.50/mo typical)
- Read AND write — full API surface (posts, comments, members, classroom, files, Auto DM)
- One `mcp` entry in `opencode.json`, no integration code to maintain

*No Skool community yet? [Launch one in 10 minutes](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "TechArticle",
  "headline": "Skool + OpenCode — Run Your Community from the Terminal via MCP",
  "description": "Connect Skool to OpenCode with one MCP entry in opencode.json. Approve members, reply to posts, publish courses from the terminal — no API code.",
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
  "mainEntityOfPage": "https://skool-api.cristiantala.com/integrations/skool-opencode/"
}
</script>
