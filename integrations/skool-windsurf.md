---
title: "Skool + Windsurf — Run Your Community from Cascade via MCP (2026)"
description: "Connect Skool to Windsurf Cascade with one MCP server entry. Approve members, reply to posts, publish courses from chat — no API code. Setup, example, gotchas."
slug: /integrations/skool-windsurf
type: integration
primary_keyword: "skool windsurf"
search_volume_monthly: 0
funnel: A
playbook: integrations
last_updated: 2026-05-21
canonical: https://ctala.github.io/skool-api-docs/integrations/skool-windsurf/
render_with_liquid: false
---


> **Quick reference (TL;DR for agents)**
> - **What this enables:** operate a Skool community from Windsurf's Cascade agent — "publish this markdown as a course lesson", "approve the verified applicants" — in plain English, inside the IDE.
> - **Method:** add the [Apify-hosted Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-windsurf) as an **MCP server** in `~/.codeium/windsurf/mcp_config.json` via Apify's MCP gateway. Cascade lists every Skool action as a tool.
> - **Config:** one `mcpServers` entry running `npx @apify/actors-mcp-server --actors=cristiantala/skool-all-in-one-api`.
> - **Auth flow:** `auth:login` once → `cookies` string cached → reuse for ~3.5 days.
> - **Cost:** Apify pay-per-event (~$0.005–$0.01 per Skool action). Windsurf on your existing plan.

## Why Windsurf + Skool?

Skool has **no official API**. Windsurf's Cascade is an agentic IDE built around a plugin store and native MCP support, with config interpolation (`${env:VAR}`, `${file:...}`) so secrets never get hardcoded. If you build inside Windsurf, managing your Skool community shouldn't mean opening a second browser tab.

The [Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-windsurf) wraps the whole Skool admin surface in a single HTTP endpoint. Added as one MCP server, every Skool action becomes a Cascade tool alongside your code tools.

Why Cascade is a good fit specifically:

1. **First-class config interpolation.** Cascade resolves `${env:APIFY_TOKEN}` and `${file:~/.secrets/skool_cookies.txt}` directly in `mcp_config.json` — you can keep your Skool `cookies` in a file and let Cascade read them on each launch, so rotation is a one-line file update.
2. **Cascade reasons across files + tools.** "Take `lesson-3.md` from this repo and publish it as a course page" chains `files`/`classroom:createPage` → `classroom:setBody` (markdown → TipTap) in one conversation.
3. **Plugin store + deeplinks.** Cascade has a curated MCP marketplace and `windsurf://` install deeplinks, so once Skool tooling matures it's discoverable the same way GitHub or Postgres MCP are.

> This is the **MCP-native** path for Windsurf. For the general MCP pattern shared across clients, see **[Skool MCP](skool-mcp.md)**.

## Setup — add the MCP server (5 minutes)

### 1. Get your Apify API token

Sign up at [apify.com](https://apify.com) — the free tier covers most communities. Token from [console.apify.com/account/integrations](https://console.apify.com/account/integrations).

### 2. Edit `mcp_config.json`

Cascade reads MCP servers from `~/.codeium/windsurf/mcp_config.json`. Open it via the **MCPs** icon in the top-right of the Cascade panel (or **Windsurf Settings → Cascade → MCP Servers**), or edit the file directly. Add the Skool actor:

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

`${env:APIFY_TOKEN}` pulls the token from your shell environment. Set it once:

```bash
export APIFY_TOKEN=apify_api_...
```

### 3. Install and verify

Open the **MCPs** panel and click the `skool` server. Cascade exposes its tools — toggle on the Skool actions you want (Cascade caps total enabled tools at 100, so you can leave rarely-used ones off). The Skool actions are now callable in any Cascade conversation. (Enterprise users: an admin must enable MCP access first.)

## Example session — publish a lesson straight from your repo

You wrote `course/llms-101/lesson-3.md` in your project and want it live in your community classroom. In Cascade you type:

> Read course/llms-101/lesson-3.md and publish it as a new page in my "Intro to LLMs" course on Skool, using the markdown as the body.

Cascade plans and executes:

```
1. (reads lesson-3.md from your workspace — native file tool)
2. skool_classroom_list_courses              → finds the "Intro to LLMs" course id
3. skool_classroom_create_page { courseId, title: "Lesson 3" }
4. skool_classroom_set_body { pageId, title, bodyMarkdown: <file contents> }
   → markdown auto-converts to Skool's TipTap format
```

Because `classroom:setBody` is idempotent, if the conversion looks off you can re-run it with the corrected markdown and the page body becomes exactly what you sent — no duplicate pages. This is the workflow that shines in an IDE: your lesson source and your published lesson stay one command apart. Full pattern: [Publish a course from markdown](../recipes/publish-course-from-markdown.md).

## How it works

```
Windsurf / Cascade                 Apify                          Skool
──────────────────                 ─────                          ─────
reads ~/.codeium/windsurf/mcp_config.json
  → spawns @apify/actors-mcp-server (stdio)
        │  Cascade picks tool + params
        ▼
[MCP tool call ──────POST JSON───→ run-sync-get-dataset-items ──→ api.skool.com]
{ action, cookies, groupSlug, ... }                              (login + WAF token +
        │                                  │                       buildId handled by actor)
        ◄──────── { success: true, data } ◄────────────────────────┘
        │
   renders result in the Cascade panel
```

Every Skool operation is one MCP tool call → one HTTP POST. The actor handles Playwright login, WAF rotation, and buildId changes — Cascade just sees a clean toolset.

## What you can ask Cascade to do — full action surface

The MCP server exposes the entire Skool admin surface as tools. You ask in plain English; Cascade maps it to one of these actions. Full params for each: [Actions reference](../docs/actions.md).

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

## Windsurf-specific gotchas

- **100-tool ceiling in Cascade.** Cascade caps the total number of enabled tools across all MCP servers at 100. The Skool actor surfaces ~25 actions — fine on its own, but if you also run GitHub, Postgres, and browser MCP servers you can hit the cap. Toggle off Skool actions you don't use (keep `posts:*`, `members:*`, `classroom:*`; drop `system:debug`).
- **Store cookies with `${file:...}`.** Cascade's file interpolation is the cleanest way to handle the ~3.5-day cookie TTL: keep `cookies` in `~/.secrets/skool_cookies.txt`, reference it, and rotation is a single file write. Note the actor takes `cookies` as a tool-call param, so you pass the interpolated value through your prompt or a wrapper, not as a server `env` var.
- **Enterprise must enable MCP.** On Teams/Enterprise plans, MCP is off until an admin turns it on and may be restricted to a whitelist. If `skool` won't load on a managed machine, ask your admin to whitelist the server ID `skool`.
- **`x402-payment-required` on every call:** Not a billing issue — it's a stale `UNDER_MAINTENANCE` flag from Apify's heuristic. Open the [actor page](https://apify.com/cristiantala/skool-all-in-one-api) in Apify Console once to reset. Details in [error handling](../docs/error-handling.md).
- **Cookies expiring silently:** when a call returns `errorCode: "WAF_EXPIRED"`, re-run `auth:login` and update the stored cookies.
- **`parentId` for comment replies:** top-level comment → `rootId == parentId == postId`. Reply to a comment → `rootId == postId`, `parentId == commentId`. Mixing these is the most common silent bug.
- **`memberId` vs `id`:** for approve/reject, pass `memberId` from `members:pending`, not the request `id`. The wrong one gives a silent 404.

## Hand this to your agent

Don't want to edit `mcp_config.json` by hand? Paste this into Cascade and it knows the setup for Skool:

```
To operate a Skool community from Windsurf Cascade, add the Apify-hosted
"Skool All-in-One API" actor (cristiantala/skool-all-in-one-api) as an MCP server.
Skool has no official API; this actor is it.

Add to ~/.codeium/windsurf/mcp_config.json:
{
  "mcpServers": {
    "skool": {
      "command": "npx",
      "args": ["-y", "@apify/actors-mcp-server", "--actors=cristiantala/skool-all-in-one-api"],
      "env": { "APIFY_TOKEN": "${env:APIFY_TOKEN}" }
    }
  }
}

Then open the MCPs panel in Cascade, click "skool", enable its tools (Cascade caps total
enabled tools at 100). Auth: call action "auth:login" with {email,password,groupSlug} ONCE,
reuse the returned `cookies` (~3.5 day TTL); re-run on errorCode "WAF_EXPIRED".
Approve/reject use params.memberId (from members:pending), NOT id.
Comment reply: parentId = comment id, rootId = post id; top-level = both postId.
Full action list + params: https://ctala.github.io/skool-api-docs/for/ai-agents/
```

For the full agent primer (function-calling specs, idempotency table, error-recovery patterns), see **[Skool for AI agents](../for/ai-agents.md)**.

## See also

- [Skool MCP](skool-mcp.md) — the general MCP pattern + the hosted gateway, shared by all MCP clients
- [Skool + Cursor](skool-cursor.md) — same MCP path, inside the Cursor editor
- [Skool + Cline](skool-cline.md) — same MCP path, inside VS Code
- [Skool + Claude Code](skool-claude-code.md) — the terminal/CLI path with a drop-in Skill
- [Skool for AI agents](../for/ai-agents.md) — full pattern library + function-calling specs
- [Actions reference](../docs/actions.md) — complete list of actions and params
- [All integrations →](index.md)

---

## Plug Skool into Windsurf today

[**→ Use the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-windsurf)

- Pay-per-event (~$0.005–$0.01 per Skool action, ~$1.50/mo typical)
- Read AND write — full API surface (posts, comments, members, classroom, files, Auto DM)
- One `mcpServers` entry, secrets via `${env:...}` / `${file:...}` interpolation

*No Skool community yet? [Launch one in 10 minutes](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "TechArticle",
  "headline": "Skool + Windsurf — Run Your Community from Cascade via MCP",
  "description": "Connect Skool to Windsurf Cascade with one MCP server entry. Approve members, reply to posts, publish courses from chat — no API code.",
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
  "mainEntityOfPage": "https://ctala.github.io/skool-api-docs/integrations/skool-windsurf/"
}
</script>
