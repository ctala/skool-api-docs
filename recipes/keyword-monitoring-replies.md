---
title: "Auto-detect Skool posts by keyword and reply (with human approval)"
description: "Monitor the Skool feed for posts mentioning specific keywords (your product, a competitor, a pain point) and draft contextual replies with LLM + human approval before publish."
slug: /recipes/keyword-monitoring-replies
type: recipe
funnel: A
section: Recipes
last_updated: 2026-05-28
render_with_liquid: false
---

# Auto-detect Skool posts by keyword and reply

Most Skool communities miss half the conversations that matter — a member mentions a pain point, another asks about an integration, someone references a competitor. You want to be **in those threads** with a useful reply, but checking the feed every 30 minutes for keywords isn't a use of your time.

This recipe is the **keyword-driven monitoring loop** used in production at [Cágala, Aprende, Repite](https://www.skool.com/cagala-aprende-repite). The cron runs every N hours, finds posts matching your keyword list that you haven't replied to yet, drafts a contextual reply with an LLM, and sends it to **Telegram for human approval** before publishing. You get a notification, click ✅ or ❌, the published reply lands in the feed under your account.

It's the same engine behind the `skool-feed-comments` skill — productionized to keep voice consistent and prevent the LLM from publishing anything cringe-worthy unsupervised.

## Quick reference (TL;DR for agents)

| | |
|---|---|
| **Goal** | Surface high-signal posts by keyword + reply with LLM + human gate |
| **Stack** | n8n / Python + LLM (Claude/GPT) + Telegram bot + the Apify-hosted actor |
| **Actions used** | [`posts:filter`](../docs/posts.md#postsfilter) → [`posts:getComments`](../docs/posts.md#postsgetcomments) → [`posts:createComment`](../docs/posts.md#postscreatecomment) |
| **Setup time** | ~30 min (workflow + Telegram bot + first keyword list) |
| **Ongoing cost** | `$0.01 × N` posts checked + `$0.01` per reply published |
| **Cadence** | Every 2-4 hours during waking hours (not 24/7 — overnight noise) |
| **Mandatory gate** | Human approval via Telegram. **NEVER auto-publish replies in production.** |

## Why human-in-the-loop is non-negotiable

LLMs are great at *drafting*, terrible at *judgment of what to say in a community thread*. A confidently wrong reply from "you" damages trust faster than no reply at all. The human gate is cheap (one Telegram tap) and catches:

- Hallucinated stats or product claims
- Wrong tone for the thread (over-formal, condescending, salesy)
- Replying to bait / hostile threads where silence is the right move
- Posts where the LLM missed the actual question

The reply is published under **your account**, not a bot. Members read "Cristian replied" — that has to mean Cristian agreed with the words.

## Prerequisites

- Apify token ([sign up free](https://console.apify.com/sign-up?fpr=cristian))
- Skool admin cookies (the account that will be credited as author of the reply) — see [Authentication](../docs/authentication.md)
- LLM API access (Claude, GPT-4, etc.)
- A Telegram bot + chat ID for receiving approvals (5-min setup via [@BotFather](https://t.me/BotFather))
- A **keyword list** — start with 5-10, expand as you learn what matters

## Step 1 — Filter the feed by keyword

`posts:filter` accepts a `query` param that searches title + body:

```json
{
  "action": "posts:filter",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "query": "n8n",
    "limit": 20,
    "since": "2026-05-28T00:00:00Z"
  }
}
```

For multiple keywords, loop the action (Skool doesn't support OR in a single call). De-dupe by `postId` afterward.

## Step 2 — Skip posts you already replied to

For each match, check if your user already commented:

```json
{
  "action": "posts:getComments",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "postId": "abc123..." }
}
```

```python
my_user_id = "cf43939d0edf46378caed98a9d46eadb"  # your Skool user_id
for comment in comments:
    if comment["author"]["id"] == my_user_id:
        skip_post()  # already replied
        break
```

This is the cheap filter — most posts in your keyword list will already have your reply once the loop has been running a few cycles.

## Step 3 — Draft reply with LLM

Send the post title + body + comments (for context of the existing thread) to your LLM with a prompt like:

```
You are drafting a reply on behalf of {your_name}, a {your_role}, in a community of {community_audience}.

POST TITLE: {title}
POST BODY: {body}
EXISTING COMMENTS: {comments}

Draft a reply that:
- Adds specific value (concrete tip, link to a recipe, useful question)
- Is 40-100 words, conversational, not salesy
- Mentions a relevant resource ONLY if it genuinely fits
- Uses neutral Spanish (no localisms)

If the post doesn't merit a reply (too vague, hostile, off-topic, already well-answered), respond with EXACTLY the string "SKIP" and nothing else.

Reply draft:
```

The `SKIP` token gives the LLM a graceful exit when there's nothing useful to say — saves you the Telegram notification.

## Step 4 — Send to Telegram for approval

```python
import requests

def send_for_approval(post, draft, telegram_bot_token, chat_id):
    text = (
        f"📬 Post: {post['title']}\n"
        f"🔗 https://www.skool.com/{group_slug}/?p={post['shortId']}\n\n"
        f"💬 Draft:\n{draft}\n\n"
        f"Approve? ✅ /approve_{post['id']} | ❌ /skip_{post['id']}"
    )
    requests.post(
        f"https://api.telegram.org/bot{telegram_bot_token}/sendMessage",
        json={"chat_id": chat_id, "text": text, "parse_mode": "HTML"}
    )
```

The Telegram bot listens for `/approve_<postId>` and `/skip_<postId>` commands. On approve, it fires the next step. On skip, it just logs the decision.

## Step 5 — Publish on approval

```json
{
  "action": "posts:createComment",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "postId": "abc123...",
    "content": "approved draft text here"
  }
}
```

Top-level comments require `postId == rootId == parentId` — the actor's `posts:createComment` defaults this correctly when you only pass `postId`. (For nested replies, see [Reply to onboarding comments](reply-onboarding-comments.md).)

## Production gotchas

- **`posts:filter` query matches title + body, NOT comments.** A post titled "What's your favorite tool?" with a comment saying "n8n is great" will NOT match `query: "n8n"`. Comment-keyword monitoring requires a separate `posts:getComments` pass — expensive at scale, narrow your post universe first.
- **De-dupe on `postId`, not `shortId`.** `posts:filter` returns both — `id` is the canonical 32-hex, `shortId` is the URL slug. Use `id` for state tracking.
- **Author check on the comment — use `user_id`, not `memberId`.** Comments have `author.id` which is the user_id (global Skool), not the per-group memberId. Confusing them = false "already replied" skips. ([Skool accounts canonical IDs](../docs/authentication.md#user-ids))
- **Telegram bot rate limits.** Don't fire >30 messages/sec from one bot. If your keyword list surfaces 50 candidate posts in one cron, batch them into a single digest message instead.
- **Cookie expiry strikes here too.** When cookies expire (~3.5 days), the cron will fail silently — the actor returns `BuildIdStaleError` but the cron tick logs a normal exit. Set up a "no replies sent in 24h" canary alert.
- **Voice drift.** If you use the same LLM prompt for months, replies start sounding generic. Re-tune the prompt every few weeks with your latest approved replies as few-shot examples.

## See also

- [Recipe: Reply to unanswered posts](reply-unanswered-posts.md) — the broader "zero-comment" sweep without keyword filter
- [Recipe: Reply to onboarding comments](reply-onboarding-comments.md) — nested replies in pinned threads (different `parentId` rules)
- [Posts API reference](../docs/posts.md) — full filter / get / comment surface

---

## Use this in production — no setup

The hardest part of building Skool automation isn't the API logic — it's the auth (cookies expire every ~3.5 days, WAF token rotation, weekly Skool buildId changes). The **[Skool All-in-One API actor on Apify](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=keyword-monitoring-replies&fpr=cristian)** handles all of that.

- Pay-per-event pricing (~$1.50/mo for typical communities)
- `posts:filter` + `posts:getComments` + `posts:createComment` are all wrapped behind one consistent JSON-over-HTTP surface
- The top-level comment `postId==rootId==parentId` quirk is handled by the action

[**→ Open the actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=keyword-monitoring-replies&fpr=cristian)

*New to Skool? [Launch your community here](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*
*Need an n8n instance? [Get started free](https://n8n.partnerlinks.io/wpqwwllhiznx) — the workflow tool we use throughout these recipes.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "HowTo",
  "name": "Auto-detect Skool posts by keyword and reply",
  "description": "Monitor the Skool feed for keywords, draft contextual replies with an LLM, and gate publishing through Telegram human approval. Production-tested pattern.",
  "totalTime": "PT30M",
  "tool": [{"@type": "HowToTool", "name": "Apify"}, {"@type": "HowToTool", "name": "LLM API"}, {"@type": "HowToTool", "name": "Telegram bot"}, {"@type": "HowToTool", "name": "Skool admin cookies"}],
  "step": [
    {"@type": "HowToStep", "name": "Filter feed by keyword", "text": "Call posts:filter with your query string. Loop for multiple keywords, de-dupe by postId."},
    {"@type": "HowToStep", "name": "Skip already-replied posts", "text": "Call posts:getComments per match, check if your user_id is in the author list. Skip if yes."},
    {"@type": "HowToStep", "name": "Draft + approve + publish", "text": "Send post context to LLM, draft a reply, send to Telegram for human approval, only publish via posts:createComment after the human taps ✅."}
  ]
}
</script>
