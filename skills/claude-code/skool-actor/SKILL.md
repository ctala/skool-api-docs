---
name: skool-actor
description: Use this skill when the user wants to read or write to a Skool community programmatically. Triggers on phrases like "list pending Skool members", "post to my Skool community", "approve all pending applicants", "publish a Skool course", "update the Auto DM message", "reply to a comment in Skool", "build a Skool course from these markdown files", or any reference to Skool automation. Use the Apify-hosted Skool All-in-One API actor.
---

# Skool All-in-One API — Claude Code Skill

This skill connects you to a Skool community via the [Apify-hosted Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api). Read AND write to posts, comments, members, classroom (courses/folders/pages), files, and group settings.

## Setup (one time)

The user needs:

1. **Apify account + token**: free tier is enough. Token from https://console.apify.com/account/integrations.
2. **Skool admin credentials** for the community.

Store in a local `.env` (never in repo):

```bash
APIFY_TOKEN=apify_api_...
SKOOL_EMAIL=admin@example.com
SKOOL_PASSWORD=...
SKOOL_GROUP_SLUG=your-community-slug   # the part after skool.com/
SKOOL_COOKIES=                          # populated after first auth:login (~3.5 day TTL)
```

**Hard rule**: never commit `.env`, never paste cookies into chat history. Treat them like API keys.

## Authentication flow

Two modes — pick based on context:

- **Mode A (cookies)**: run `auth:login` once, save `cookies` value, pass it in every other call. Fast (~2s/call) and cheap. **Default to this.**
- **Mode B (email/password every call)**: simpler for one-off scripts but ~10s/call and ~5× more expensive. Use only when no cookie storage is available.

When the user runs an action and gets `errorCode: WAF_EXPIRED`, that's the cue to re-run `auth:login` and update the cached cookies.

## Generic call shape

Every action goes through one HTTP call:

```bash
curl -X POST "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=$APIFY_TOKEN&build=latest&timeout=90" \
  -H 'Content-Type: application/json' \
  -d '{
    "action": "<namespace>:<operation>",
    "cookies": "...",
    "groupSlug": "...",
    "params": { /* per-action */ }
  }'
```

Helper scripts in `scripts/` wrap the most common actions (use them when relevant):

- `scripts/login.sh` — `auth:login` (Mode A bootstrap)
- `scripts/post.sh` — `posts:create` shortcut
- `scripts/comment.sh` — `posts:createComment` shortcut
- `scripts/approve.sh` — `members:approve` shortcut (single applicant)
- `scripts/batch-approve.sh` — `members:batchApprove` shortcut (N applicants; takes ids as args or on stdin)

## Action reference

Decide the action, then assemble `params` from this table.

### Posts & Comments (Skool's posts and comments are the same object)

| Action | Required params | Notes |
|---|---|---|
| `posts:list` | — | Optional: `page`, `sort`, `limit` |
| `posts:filter` | — | Combine `since`, `until`, `unanswered`, `labelId`, `limit` |
| `posts:get` | `postId` | |
| `posts:create` | `title`, `content` | Plain text only — NO HTML, NO markdown. Optional: `labelId`, `videoIds` |
| `posts:update` | `postId` + (`title` and/or `content`) | Edits comment if `postId` is a comment id |
| `posts:delete` | `postId` | Cascades to all replies |
| `posts:createComment` | `rootId`, `parentId`, `content` | **Top-level comment**: `rootId == parentId == postId`. **Nested reply**: `rootId == postId` (always), `parentId == commentId` |
| `posts:pin` / `posts:unpin` | `postId` | |
| `posts:vote` | `postId`, `vote: "up" \| ""` | |
| `posts:getComments` | `postId` | REST, fast (~2s). Returns nested tree, max ~35 top-level. Free read |
| `posts:getCommentsFull` | `postId` OR `postSlug` | Playwright DOM scroll, slow (~30-60s), **no cap** — gets every reply. $0.05 scrape-operation event. Use when `posts:getComments` truncates |

### Members

| Action | Required params | Notes |
|---|---|---|
| `members:list` | — | Optional `page`, `limit` |
| `members:pending` | — | Returns applicants in approval queue. **Use `memberId` (NOT `id`) for subsequent approve/reject calls** |
| `members:approve` | `memberId` | |
| `members:reject` | `memberId` | |
| `members:ban` | `memberId` | Permanent — confirm with user before invoking |
| `members:batchApprove` | `memberIds: string[]` | Per-item results in response |

**Waitlist review flow (human-in-the-loop)** — when the user asks to "review/clear the pending members": `members:pending` → screen each applicant against the user's criteria (LinkedIn reachable + specific screening answer + acquisition channel) → collect the `memberId`s that pass → `members:batchApprove` → re-run `members:pending` to verify the queue. Show the user the screened list and wait for confirmation before approving. Full walkthrough: [Recipe — Review and batch-approve your Skool waitlist](https://github.com/ctala/skool-api-docs/blob/main/recipes/review-and-batch-approve-waitlist.md). For fully automated AI screening instead, see the [auto-approve recipe](https://github.com/ctala/skool-api-docs/blob/main/recipes/auto-approve-members-n8n.md).

### Events (calendar)

| Action | Required params | Notes |
|---|---|---|
| `events:list` | — | All calendar events (past + future). Optional `page`, `limit`. Each event has `nextOccurrence`, `timezone`, `occurrenceId` |
| `events:upcoming` | — | Future events only, sorted ascending. Optional `limit` |

### Classroom (courses, folders, pages)

| Action | Required params | Notes |
|---|---|---|
| `classroom:listCourses` | — | |
| `classroom:getTree` | `courseId` | Recursive tree |
| `classroom:createCourse` | `title` | Optional: `desc`, `coverImage` + `coverImageFile`, `privacy` (0-4), `minTier`, `amount`, `state` |
| `classroom:createFolder` | `parentCourseId`, `title` | |
| `classroom:createPage` | `courseId`, `parentId`, `title` | `parentId` = course id (top-level page) or folder id (nested) |
| `classroom:setBody` | `pageId`, `title`, `bodyMarkdown` (or `bodyRaw`) | Markdown auto-converted to TipTap. Pass `bodyRaw` if you have `[v2]<JSON>` already |
| `classroom:updateCourse` | `courseId` + at least one field to change | **Read-then-write**: any field omitted is preserved. Cost: +1 GET (~200ms) per call. Use this for ALL course edits (cover, title, desc, privacy, tier) |
| `classroom:deleteUnit` | `id` | Cascades. Confirm with user before destructive deletes |
| `classroom:updateResources` | `pageId`, `fileIds: string[]` | Replace lesson Resources (attach/detach files). Each `fileId` from prior `files:uploadFile` call. `[]` detaches all |

### Files & Groups

| Action | Required params | Notes |
|---|---|---|
| `files:uploadImage` | `bufferBase64` OR `imageUrl` | Upload a **cover image**. Returns `{coverImageUrl, coverImageFile}` — pass BOTH to subsequent course/group calls |
| `files:uploadFile` | `bufferBase64` OR `fileUrl`, `filename` | Upload a **private file** (PDF, JSON, ZIP, etc) for classroom Resources. Returns `{fileId}` to pass to `classroom:updateResources` |
| `groups:get` | `slug` | Group metadata (incl. `label_options` for posts:create labelId values) |
| `groups:setAutoDM` | `message` | 300-char limit. Tokens: `#NAME#`, `#GROUPNAME#`. Plugin must be enabled in Settings → Plugins |

### System

| Action | Required params | Notes |
|---|---|---|
| `system:health` | — | No auth, no Skool calls. Healthcheck only |
| `system:debug` | `cookies`, `groupSlug` | SSR diagnostics: homepage status + buildId extracted + SSR fetch result + REST client probe. Use for debugging |
| `auth:login` | `email`, `password`, `groupSlug` | Returns `cookies` (~3.5 day TTL) + `expiresAt` + `buildId` |

## Constraints

- **Title length**: ≤50 chars on courses, folders, pages (UTF-16 — emojis count as 2). Validate **before** the network call.
- **Auto DM**: ≤300 chars
- **Post content**: plain text — Skool doesn't render HTML or markdown
- **Course page body**: rich (markdown auto-converted to TipTap)
- **Rate limit**: ~25 writes/min (Skool's hard limit). The actor queues; don't add your own retry loop.
- **R-PUT-COURSE**: NEVER call `PUT /courses/{id}` directly with a partial body — it silently resets `privacy` to 0. Always use `classroom:updateCourse` action which handles read-then-write.

## Error handling

The actor never throws. Every call returns either `{success: true, ...}` or `{success: false, errorCode, errorCategory, hint, retryable}`. Always check `success` before treating the response as a result.

When you see a failure:

1. Read the `hint` field — it tells you what to do
2. If `errorCode === "WAF_EXPIRED"` → re-run `auth:login`, update cookies, retry
3. If `errorCode === "MISSING_CATEGORY"` → call `groups:get` to fetch `label_options`, ask the user which category, retry with `params.labelId`
4. If `errorCode === "TITLE_TOO_LONG"` → trim the title, retry
5. If `errorCode === "RATE_LIMIT"` → wait 60s, retry
6. If `errorCategory === "unknown_error"` → surface the `stack` to the user; this is a real bug

## Pre-flight checks before destructive actions

Before invoking `members:ban`, `classroom:deleteUnit`, or `posts:delete` of more than 1 item:

1. List what will be affected (`classroom:getTree`, `members:list`, etc.)
2. Show the user the list
3. Wait for explicit confirmation
4. Then act

Never assume "delete all" means "delete all" without showing scope first.

## When to use this skill vs editing Skool UI directly

**Use this skill when**:
- The user wants automation, scheduling, or batch operations
- The user is integrating Skool into a workflow (n8n, Make, custom code)
- The user needs reproducible publishing (course from markdown, scheduled posts)

**Recommend the Skool UI when**:
- Single one-off action that takes 5 seconds in the UI
- Anything involving promotions to admin (action not exposed)
- Anything involving Apply form questions, Discovery keywords, or other settings the actor doesn't yet wrap

## Documentation

Full reference + recipes: https://github.com/ctala/skool-api-docs

- [Getting Started](https://github.com/ctala/skool-api-docs/blob/main/docs/getting-started.md)
- [Authentication](https://github.com/ctala/skool-api-docs/blob/main/docs/authentication.md) — cookies, WAF, the `x402-payment-required` confusion
- [Actions Reference](https://github.com/ctala/skool-api-docs/blob/main/docs/actions.md)
- [Error handling](https://github.com/ctala/skool-api-docs/blob/main/docs/error-handling.md)
- [Recipes](https://github.com/ctala/skool-api-docs/tree/main/recipes)
- [AI Agents integration guide](https://github.com/ctala/skool-api-docs/blob/main/docs/agents.md)
