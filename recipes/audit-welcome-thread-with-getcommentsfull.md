---
title: "Audit a long Skool welcome thread (>35 comments) with getCommentsFull"
description: "Skool's API caps comment listings at ~35 — getCommentsFull scrapes the whole welcome thread so you can find members you never replied to."
slug: /recipes/audit-welcome-thread-with-getcommentsfull
type: recipe
funnel: A
section: Recipes
last_updated: 2026-07-12
render_with_liquid: false
---

# Audit a long welcome thread (>35 comments) with `posts:getCommentsFull`

**Use case**: Your community has a pinned "Introduce yourself" thread that grew to hundreds of comments. You want to verify that every new member got a personalized welcome reply from you — but Skool's REST API caps comment listings at ~35 per thread. How do you scrape the full thread and find members you haven't replied to?

This recipe uses `posts:getCommentsFull` — a Playwright-based action that bypasses the REST cap by scrolling the thread page and extracting every comment from the DOM. Costs $0.05 per invocation (the scrape fee) but returns the full thread.

## When you need this

- Welcome thread with 100+ introductions
- AMA or weekly discussion threads that grew beyond 35 comments
- Auditing comment moderation (find which top-level comments lack admin replies)
- Member analytics on who introduced themselves but never came back

## What you'll need

- Apify token + cookies for your Skool community (run `auth:login` once)
- Post ID + slug of the long thread (find in the URL or via `posts:list`)
- Your own user ID in Skool (to detect which replies are yours)

## The recipe

### Step 1 — Get the full comment tree

```bash
curl -X POST "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=$APIFY_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "action": "posts:getCommentsFull",
    "groupSlug": "your-community-slug",
    "cookies": "auth_token=...; client_id=...; aws-waf-token=...",
    "params": {
      "postId": "3bc910b12bd0443f886e13c5ac28a08a",
      "postSlug": "paso-2-presentate"
    }
  }'
```

**Response shape** (each comment is a flat object with `isReply` flag):

```json
[
  {
    "id": "scraped-0",
    "content": "Hi! I'm Jane, founder of...",
    "author": { "firstName": "Jane", "lastName": "Doe", "slug": "janedoe" },
    "isReply": false
  },
  {
    "id": "scraped-1",
    "content": "Welcome Jane! Tell us about...",
    "author": { "firstName": "Cristian", "lastName": "Tala", "slug": "cristian" },
    "isReply": true
  }
]
```

### Step 2 — Identify top-level comments without admin replies

Group the flat array into top-level + nested replies, then filter:

```javascript
// pseudo-code in n8n Code node or Python
const ADMIN_NAMES = ['Cristian Tala'];

let topLevels = [];
let current = null;
for (const c of comments) {
  if (c.isReply) {
    if (current) current.replies.push(c);
  } else {
    current = { ...c, replies: [] };
    topLevels.push(current);
  }
}

const unanswered = topLevels.filter(tl => {
  // Skip top-level from admin (it's a regular post, not an intro)
  if (ADMIN_NAMES.some(n => tl.author.firstName + ' ' + tl.author.lastName === n)) {
    return false;
  }
  // Did any admin reply?
  return !tl.replies.some(r =>
    ADMIN_NAMES.some(n => r.author.firstName + ' ' + r.author.lastName === n)
  );
});

console.log(`${unanswered.length} members need a welcome reply`);
```

### Step 3 — Generate personalized drafts (optional)

Pipe each unanswered intro through an LLM with your community context:

```javascript
// For each unanswered, call LLM
for (const member of unanswered) {
  const prompt = `You are the founder of [community name]. A new member just introduced themselves:

"${member.content}"

Write a warm, specific, 3-5 sentence welcome reply that:
- References ONE concrete detail from their intro (not generic praise)
- Offers ONE actionable tip relevant to what they shared
- Invites them to post a specific question in the feed

Tone: founder-to-founder, no marketing fluff, no emojis in chains.`;

  const reply = await llm(prompt);
  drafts.push({ member: member.author.firstName, content: reply });
}
```

### Step 4 — Post the replies (with human approval)

**Don't auto-post**. Generate drafts, send to Telegram or a review queue, only post after manual approval:

```bash
curl -X POST "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=$APIFY_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "action": "posts:createComment",
    "groupSlug": "your-community-slug",
    "cookies": "auth_token=...; ...",
    "params": {
      "rootId": "3bc910b12bd0443f886e13c5ac28a08a",
      "parentId": "<comment_id_of_the_member>",
      "content": "Approved draft text..."
    }
  }'
```

**Note**: the `comment_id` of the member is NOT the same as `scraped-0` (that's a synthetic ID from Playwright). For posting replies you need the real Skool ID, which `posts:getCommentsFull` doesn't return. Either:
- Use `posts:getComments` (REST, max 35) to get real IDs for the most recent comments and cross-reference by author + content
- Or do this as a one-shot audit (identify who needs reply, then go reply manually in the Skool UI)

The current limitation: `posts:getCommentsFull` is read-only audit. For programmatic replies to old comments, combine with `posts:getComments` (REST, ~35 most recent) to get real IDs and cross-reference by author + content. Resolving an arbitrary comment ID for older comments programmatically is a known gap — track [issues on the repo](https://github.com/ctala/skool-api-docs/issues) if you hit this.

## Pricing

| Action | Cost | When charged |
|---|---|---|
| `posts:getCommentsFull` | $0.05 | Per invocation (the scrape fee) |
| Dataset items returned | $0.005 × N | One result per comment in thread |

For a 200-comment thread: ~$0.05 + (200 × $0.005) = ~$1.05 per audit run. Most communities run this once per week or monthly.

## Why not just use `posts:getComments`?

| | `posts:getComments` (REST) | `posts:getCommentsFull` (Playwright) |
|---|---|---|
| Speed | ~2s | ~30-60s |
| Cost | $0 (just dataset) | $0.05 + dataset |
| Max comments per thread | ~35 (25 head + 10 tail) | All (verified up to 200+) |
| Returns real comment IDs | Yes | No (synthetic `scraped-N`) |
| Best for | New threads, recent comments | Audits, long threads |

Use `posts:getComments` for day-to-day. Use `posts:getCommentsFull` when you specifically need full coverage and audit insights are worth more than the $0.05.

## Related

- [Reply to unanswered posts automatically](reply-unanswered-posts.md) — same pattern for top-level posts (not nested comments)
- [Auto DM new members](auto-dm-new-members.md) — prevent the welcome thread from getting buried by automating the first-touch DM
- [Community analytics to NocoDB](community-analytics-to-nocodb.md) — export this audit data for tracking over time
