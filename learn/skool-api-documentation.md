---
title: "Skool API Documentation — Complete Action Reference (2026)"
description: "Skool API documentation: every action, every param, response shapes, error codes. Auth, posts, members, classroom, files, groups. Apify-hosted."
slug: /learn/skool-api-documentation
type: glossary
primary_keyword: "skool api documentation"
search_volume_monthly: 20
funnel: A
playbook: glossary
last_updated: 2026-05-19
canonical: https://github.com/ctala/skool-api-docs/blob/main/learn/skool-api-documentation.md
---


> **TL;DR.** Skool has no official API documentation because it has no official API. The complete unofficial documentation is this repo + the [Apify-hosted Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=glossary&utm_campaign=skool-api-documentation). Below: structure, where each topic lives, how to read the actor's structured responses.

## Quick navigation

| You want to... | Read |
|---|---|
| Make your first API call in 60 seconds | [Getting Started](../docs/getting-started.md) |
| Understand the auth flow (cookies, WAF token) | [Authentication](../docs/authentication.md) |
| See every action and its params | [Actions reference](../docs/actions.md) |
| Understand structured errors | [Error handling](../docs/error-handling.md) |
| Read/write posts and comments | [Posts & Comments](../docs/posts.md) |
| Manage members (approve, reject, ban, list) | [Members](../docs/members.md) |
| Publish courses, folders, pages | [Classroom](../docs/classroom.md) |
| Upload cover images | [Files](../docs/files.md) |
| Configure groups + Auto DM | [Groups](../docs/groups.md) |
| Integrate from AI agents (Claude / GPT / MCP) | [AI Agents integration](../docs/agents.md) |

## How the actor's API works

Every Skool operation is a single HTTP POST to one URL:

```
POST https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token={APIFY_TOKEN}&build=latest&timeout=90
```

Body always:

```json
{
  "action": "<namespace>:<operation>",
  "cookies": "<long cookie string from auth:login>",
  "groupSlug": "<your-community-slug>",
  "params": { /* action-specific */ }
}
```

Response is **always** one of two shapes:

```json
{ "success": true, "data": { ... } }
```

or

```json
{ "success": false, "errorCode": "...", "errorCategory": "...", "hint": "...", "retryable": true }
```

The actor never throws. Every error is a structured payload your code (or AI agent) can branch on.

## Action namespaces

| Namespace | Operations | Purpose |
|---|---|---|
| `auth` | `login` | Get cookies (every other call needs them) |
| `system` | `health`, `debug` | Health checks |
| `posts` | `list`, `filter`, `get`, `create`, `update`, `delete`, `pin`, `unpin`, `vote`, `createComment`, `getComments` | Posts + comments |
| `members` | `list`, `pending`, `approve`, `reject`, `ban`, `batchApprove` | Member admin |
| `classroom` | `listCourses`, `getTree`, `createCourse`, `createFolder`, `createPage`, `setBody`, `updateCourse`, `deleteUnit` | Courses + folders + pages |
| `files` | `uploadImage` | Cover image uploads |
| `groups` | `get`, `setAutoDM` | Group metadata + Auto DM |

Full param tables for each: [actions.md](../docs/actions.md).

## Response shape — read your way through it

```json
{
  "success": true,
  "data": {
    "posts": [
      {
        "id": "abc123...",
        "title": "...",
        "content": "...",
        "createdAt": "2026-05-19T13:45:00Z",
        "author": {"id": "...", "firstName": "...", "lastName": "..."},
        "commentsCount": 5,
        "labelId": "..."
      }
    ],
    "pagination": {"page": 1, "hasMore": true}
  }
}
```

For comments specifically, see [Posts & Comments](../docs/posts.md) — the data model unifies posts and comments as one tree.

## Error code catalog (most common)

| `errorCode` | Meaning | What to do |
|---|---|---|
| `WAF_EXPIRED` | Cookies expired (~3.5 days) | Re-run `auth:login`, store new cookies, retry |
| `MISSING_CATEGORY` | `posts:create` needs a `labelId` | Call `groups:get` to list label_options, pass labelId |
| `TITLE_TOO_LONG` | Course/folder/page title >50 chars | Trim title (UTF-16, emojis count as 2) |
| `RATE_LIMIT` | Skool's 25/min cap hit | Wait 60s, retry. Actor queues automatically. |
| `MEMBER_NOT_FOUND` | Used `id` instead of `memberId` | Re-fetch with `members:pending`, use `memberId` field |
| `UNDER_MAINTENANCE` | Apify-side flag (rare, not a real maintenance) | Open the actor in Apify console once to reset |

Full catalog: [error-handling.md](../docs/error-handling.md).

## Idempotency table

| Action | Safe to retry? |
|---|---|
| `auth:login` | Yes (returns new cookies each time) |
| `posts:create` | **No** — creates a new post |
| `posts:update` | Yes |
| `posts:delete` | Yes |
| `posts:createComment` | **No** |
| `members:approve` | Yes |
| `members:batchApprove` | Yes |
| `classroom:setBody` | Yes |
| `classroom:updateCourse` | Yes (read-then-write) |
| `files:uploadImage` | **No** — uploads a new copy each call |
| `groups:setAutoDM` | Yes |

If your script can retry on transient errors, lock around the non-idempotent ones with a "have I done this already?" check.

## Constraints

- **Title length**: ≤50 chars UTF-16 (emojis count as 2) for courses, folders, pages
- **Auto DM**: ≤300 chars
- **Post content**: plain text — HTML/markdown is rendered as raw text
- **Course page body**: rich, markdown auto-converts to TipTap
- **Rate limit**: ~25 writes/min globally (Skool-side)
- **Cookies TTL**: ~3.5 days

## Where docs live

- **This repository** — `github.com/ctala/skool-api-docs` (mirror of the actor's official docs)
- **Apify actor page** — quick-start, pricing, version notes, input schema reference
- **Changelog** — [CHANGELOG.md](https://github.com/ctala/skool-api-docs/blob/main/CHANGELOG.md)

## Related

- [Skool API (pillar)](skool-api.md)
- [Authentication](../docs/authentication.md)
- [Actions reference](../docs/actions.md)
- [AI Agents integration](../docs/agents.md)
- [Recipes](../recipes/)

---

## Use it in production today

[**→ Open the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=glossary&utm_campaign=skool-api-documentation)

Pay-per-event pricing (~$1.50/mo typical). Read AND write. Structured response contract designed for AI agents.

*No Skool community yet? [Launch one in 10 minutes](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{"@context":"https://schema.org","@type":"DefinedTerm","name":"Skool API Documentation","description":"Complete unofficial Skool API documentation for posts, comments, members, classroom, files, groups via the Apify-hosted Skool All-in-One API actor.","inDefinedTermSet":"https://github.com/ctala/skool-api-docs"}
</script>
