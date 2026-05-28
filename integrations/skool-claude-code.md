---
title: "Skool + Claude Code — Run Your Community from the Terminal (2026)"
description: "Operate Skool from Claude Code with a drop-in Skill. Approve members, reply to posts, publish courses in natural language — no API code to write. Setup, example session, helper scripts."
slug: /integrations/skool-claude-code
type: integration
primary_keyword: "skool claude code"
search_volume_monthly: 10
funnel: A
playbook: integrations
last_updated: 2026-05-21
canonical: https://ctala.github.io/skool-api-docs/integrations/skool-claude-code/
render_with_liquid: false
---


> **Quick reference (TL;DR for agents)**
> - **What this enables:** operate a Skool community straight from the Claude Code terminal — "approve the pending members with a real LinkedIn", "publish this markdown as a course" — in plain English, no API code to write.
> - **Method:** a drop-in Claude Code **Skill** (`~/.claude/skills/skool-actor/`) that wraps the [Apify-hosted Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-claude-code&fpr=cristian). Claude Code reads the SKILL.md, picks the right action, runs it.
> - **Auth flow:** `auth:login` once → `cookies` string cached in env → reuse for ~3.5 days.
> - **Latency:** ~2s per action (cookies cached) / ~10s (`auth:login` cold start).
> - **Cost:** Apify pay-per-event (~$0.005–$0.01 per Skool action). Claude Code on your existing Anthropic plan.

## Why Claude Code specifically?

Skool has **no official API**. If you live in the terminal — building, scripting, shipping — you don't want to leave your editor, open the Skool web UI, and click through member approvals or course uploads by hand.

Claude Code is an **agentic CLI**: it reads your repo, runs commands, and chains steps toward a goal. The [Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-claude-code&fpr=cristian) is the missing piece — it turns every Skool admin action into one HTTP call. Together they let you run your community as naturally as you run `git`.

What makes Claude Code a better fit than the raw API or Claude Desktop:

1. **Drop-in Skill, zero integration code.** You don't write a tool-use schema or an MCP config — you install a Skill file and Claude Code knows all 30+ actions, their params, and the gotchas.
2. **It already has a shell.** `auth:login`, `curl`, reading a markdown file to publish as a course — Claude Code runs these directly. No glue code.
3. **Multi-step judgment in one prompt.** "Review the waitlist, approve verified LinkedIn, summarize the rest" becomes a single sentence; Claude Code reads `members:pending`, screens, and calls `members:batchApprove`.

> Looking for the Anthropic **API** (tool-use) or **Claude Desktop + MCP** instead? See **[Skool + Claude](skool-claude.md)**. This page is the deep dive on the **Claude Code CLI + Skill**.

## Setup — install the Skill (5 minutes)

### 1. Get your Apify API token

Sign up at [apify.com](https://apify.com?fpr=cristian) — the free tier covers most communities. Grab a token from [console.apify.com/account/integrations](https://console.apify.com/account/integrations?fpr=cristian).

### 2. Install the drop-in Skill

The Skill (and its helper scripts) are maintained in this repo. Install them into Claude Code:

```bash
mkdir -p ~/.claude/skills/skool-actor/scripts

# the Skill itself
curl -L https://raw.githubusercontent.com/ctala/skool-api-docs/main/skills/claude-code/skool-actor/SKILL.md \
  -o ~/.claude/skills/skool-actor/SKILL.md

# helper scripts (shortcuts for the most common actions)
for s in login.sh post.sh comment.sh approve.sh batch-approve.sh; do
  curl -L https://raw.githubusercontent.com/ctala/skool-api-docs/main/skills/claude-code/skool-actor/scripts/$s \
    -o ~/.claude/skills/skool-actor/scripts/$s
  chmod +x ~/.claude/skills/skool-actor/scripts/$s
done
```

### 3. Set your credentials in `~/.zshrc`

```bash
export APIFY_TOKEN=apify_api_...
export SKOOL_EMAIL=admin@yourcommunity.com
export SKOOL_PASSWORD=your-skool-password
export SKOOL_GROUP_SLUG=your-community-slug   # the part after skool.com/
export SKOOL_COOKIES=                          # filled after the first auth:login (~3.5 day TTL)
```

Restart Claude Code. The Skill auto-activates when you mention Skool — no flag to pass.

## Example session — clear the waitlist from the terminal

You're in any Claude Code conversation and type:

> List my pending Skool members and approve the ones with a real LinkedIn. Show me the rest so I can decide.

Claude Code reads the Skill and runs, in sequence:

```
1. members:pending                    → fetches the approval queue
2. (screens each: LinkedIn reachable? survey answer specific? channel?)
3. members:batchApprove               → approves the clear yeses in one call
4. prints the borderline ones for you → you decide the edge cases
```

End-to-end this replaces ~10 minutes of clicking through the Skool admin UI, and it costs about a cent per approved member. Full walkthrough: [Review & batch-approve your waitlist](../recipes/review-and-batch-approve-waitlist.md).

## How it works

```
Claude Code (your terminal)        Apify                          Skool
───────────────────────────        ─────                          ─────
reads ~/.claude/skills/skool-actor/SKILL.md
        │  picks action + params
        ▼
[curl ───────────POST JSON───────→ run-sync-get-dataset-items ──→ api.skool.com]
{ action, cookies, groupSlug, ... }                              (login + WAF token +
        │                                  │                       buildId handled by actor)
        ◄──────── { success: true, data } ◄────────────────────────┘
        │
   reports back in plain English
```

Every Skool operation is one HTTP POST. No SDK, no tool-use schema to maintain — the SKILL.md *is* the integration. The actor handles Playwright login, WAF token rotation, and Skool buildId changes for you.

## Helper scripts

The Skill bundles shortcuts for the highest-frequency actions, so Claude Code (or you) can run them directly:

| Script | Action | Use |
|---|---|---|
| `login.sh` | `auth:login` | Bootstrap the `cookies` value (~3.5 day TTL) |
| `post.sh` | `posts:create` | Publish a community post |
| `comment.sh` | `posts:createComment` | Reply to a post or comment |
| `approve.sh` | `members:approve` | Approve a single applicant |
| `batch-approve.sh` | `members:batchApprove` | Approve N applicants in one run (args or stdin) |

For everything else (classroom, files, Auto DM, events), Claude Code calls the actor action directly per the SKILL.md action reference.

## What you can ask Claude Code to do — full action surface

The Skill exposes the entire Skool admin surface. You ask in plain English; Claude Code maps it to one of these actions. Full params for each: [Actions reference](../docs/actions.md).

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
| `members:ban` | Ban a member (destructive — Claude Code confirms first) |

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

## Production gotchas

- **`x402-payment-required` on every call:** Not a billing issue — it's a stale `UNDER_MAINTENANCE` flag from Apify's heuristic. Open the [actor page](https://apify.com/cristiantala/skool-all-in-one-api?fpr=cristian) in Apify Console once to reset. Details in [error handling](../docs/error-handling.md).
- **Cookies expiring silently:** when a call returns `errorCode: "WAF_EXPIRED"`, re-run `auth:login` (or `login.sh`) and update `SKOOL_COOKIES`. The Skill tells Claude Code to do this automatically when it reads the `hint`.
- **`parentId` for comment replies:** top-level comment → `rootId == parentId == postId`. Reply to a comment → `rootId == postId`, `parentId == commentId`. Mixing these is the most common silent bug — the SKILL.md spells it out so Claude Code gets it right.
- **`memberId` vs `id`:** for approve/reject, pass `memberId` from `members:pending`, not the `id` (request id). The wrong one gives a silent 404.
- **Rate limit ~25 writes/min:** Skool's hard limit. The actor queues internally — don't ask Claude Code to add a retry loop on top.
- **Confirm before destructive batches:** for `members:ban`, `classroom:deleteUnit`, or deleting multiple posts, the Skill instructs Claude Code to show you the scope and wait for your "go".

## Hand this to your agent

Don't want to install the Skill? Paste this primer into Claude Code (or any coding agent — Cursor, Cline, your own loop) and it knows how to drive Skool in one shot:

```
You can operate a Skool community through the Apify-hosted "Skool All-in-One API"
actor (cristiantala/skool-all-in-one-api). Skool has no official API; this actor is it.

Every action is ONE HTTP POST:
  POST https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=$APIFY_TOKEN&build=latest&timeout=90
  body: { "action": "<namespace>:<op>", "cookies": "$SKOOL_COOKIES",
          "groupSlug": "<your-slug>", "params": { ...per action... } }

Auth: call action "auth:login" with {email,password,groupSlug} ONCE, save the returned
  `cookies` string, reuse it (~3.5 day TTL). On errorCode "WAF_EXPIRED", re-run auth:login.

Actions: posts:* (list/filter/get/create/update/delete/createComment/pin/vote/getComments)
  · members:* (list/pending/approve/reject/ban/batchApprove)
  · events:* (list/upcoming) · classroom:* (listCourses/getTree/createCourse/createFolder/
  createPage/setBody/updateCourse/updateResources/deleteUnit) · files:* (uploadImage/uploadFile)
  · groups:* (get/setAutoDM) · system:* (health/debug) · auth:login
  Full params: https://ctala.github.io/skool-api-docs/docs/actions/

Rules:
  - Members approve/reject use params.memberId (from members:pending), NOT id.
  - Comment reply: parentId = the comment id, rootId = the post id. Top-level: both = postId.
  - Posts are plain text (no markdown/HTML). Course lesson bodies accept markdown via setBody.
  - ~25 writes/min hard limit; the actor queues — do NOT add your own retry loop.
  - Every response is { success:true, data } or { success:false, errorCode, hint } — read `hint` to recover.
```

This is the same surface the bundled Skill encodes — use the Skill for the polished drop-in experience, or this primer for a quick, tool-agnostic start.

## See also

- [Skool + Claude](skool-claude.md) — the Anthropic **API** (tool-use) and **Claude Desktop + MCP** paths
- [Skool MCP](skool-mcp.md) — make Skool actions natively callable in any MCP client (Cursor, Cline, Claude Desktop)
- [Recipe: Review & batch-approve your waitlist](../recipes/review-and-batch-approve-waitlist.md)
- [Recipe: Publish a course from markdown](../recipes/publish-course-from-markdown.md)
- [Skool for AI agents](../for/ai-agents.md) — full pattern library + function-calling specs
- [All integrations →](index.md)

---

## Plug Skool into Claude Code today

[**→ Use the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-claude-code&fpr=cristian)

- Pay-per-event (~$0.005–$0.01 per Skool action, ~$1.50/mo typical)
- Read AND write — full API surface (posts, comments, members, classroom, files, Auto DM)
- Drop-in Skill, no integration code to maintain

*No Skool community yet? [Launch one in 10 minutes](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "TechArticle",
  "headline": "Skool + Claude Code — Run Your Community from the Terminal",
  "description": "Operate Skool from Claude Code with a drop-in Skill. Approve members, reply to posts, publish courses in natural language — no API code to write.",
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
  "mainEntityOfPage": "https://ctala.github.io/skool-api-docs/integrations/skool-claude-code/"
}
</script>
