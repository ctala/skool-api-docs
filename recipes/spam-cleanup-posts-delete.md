---
title: "Auto-detect and delete spam posts in your Skool community"
description: "Find low-signal or spam posts (off-topic, promo, bot drops) and delete them in bulk via posts:delete. Human-in-the-loop approval gate optional but recommended."
slug: /recipes/spam-cleanup-posts-delete
type: recipe
funnel: A
section: Recipes
last_updated: 2026-05-28
render_with_liquid: false
---

# Auto-detect and delete spam posts

Spam in a Skool community comes in three flavors: outright promo drops (members posting their own services unrelated to the community), AI-generated low-effort posts (vague questions designed to farm attention), and off-topic content (politics, crypto pumps in a marketing community). The Skool admin can delete posts one by one, but if you've been away for a week and your feed has 20 things to clean up, that's tedious.

This recipe is the **bulk cleanup flow** — filter the feed by spam signals, review the candidates, delete in bulk. Use it as a weekly housekeeping pass, not as a real-time auto-moderator (that needs human judgment in the loop).

## Quick reference (TL;DR for agents)

| | |
|---|---|
| **Goal** | Bulk-delete low-signal posts after a quick human review |
| **Stack** | Any HTTP client + the Apify-hosted actor |
| **Actions used** | [`posts:filter`](../docs/posts.md#postsfilter) → [`posts:delete`](../docs/posts.md#postsdelete) (one call per post) |
| **Setup time** | ~5 min |
| **Ongoing cost** | `$0.01 × N` deletions |
| **Key gotcha** | `posts:delete` is **irreversible** — Skool doesn't have a soft-delete / trash bin |
| **Mandatory pattern** | Review the list BEFORE deleting. Don't loop `filter → delete` without a human gate |

## Prerequisites

- Apify token ([sign up free](https://console.apify.com/sign-up?fpr=cristian))
- Skool admin cookies — **owner or admin** role is required for `posts:delete` (members can only delete their own posts)
- A written rubric of what counts as spam in **your** community (varies wildly by topic + culture)

## Define "spam" before you sweep

Skool doesn't have a built-in spam classifier. What's promo in a creator community is signal in a B2B sales community. Have a clear filter:

| Delete | Signal |
|---|---|
| **Off-topic promo** | Member posts a link to their service / store / Discord with no relation to the community's topic |
| **AI-generated vague filler** | "What do you think about AI?" / "How's everyone doing?" with zero context, no follow-up engagement |
| **Bot drops** | New account, first post is a link to a sketchy site, no profile bio |
| **Crypto / MLM / get-rich-quick** | Pumps, recruiting threads disguised as questions |

Don't delete:

- Genuine beginners asking obvious questions (better: pin a "Start here" thread)
- Off-format but earnest contributions (vent posts, intros)
- Anything you're unsure about — leave it, ask the member, or move it to a different category

## Step 1 — Filter spam candidates

Three filter patterns by signal type:

**By keyword in title/body:**
```json
{
  "action": "posts:filter",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "query": "telegram channel",
    "since": "2026-05-21T00:00:00Z"
  }
}
```

**By low engagement (0 comments + > 48h old):**
```json
{
  "action": "posts:list",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "limit": 50 }
}
```

Then filter client-side: `commentsCount === 0 AND createdAt < now - 48h AND authorIsNew`.

**By new-author pattern (joined today, posting links):**
List + filter for posts where `author.joinedAt > today - 24h` AND `body contains http`.

Each pattern surfaces a different spam flavor — chain them all in your weekly sweep.

## Step 2 — REVIEW the candidate list

Print the candidates to your terminal / a Google Sheet / a Telegram thread before deleting:

```python
for post in candidates:
    print(f"[{post['id']}] {post['author']['firstName']} — {post['title'][:80]}")
    print(f"  URL: https://www.skool.com/{group_slug}/?p={post['shortId']}")
    print(f"  Body: {post['body'][:200]}")
    print(f"  Author joined: {post['author']['joinedAt']} | comments: {post['commentsCount']}")
    print()
```

Manually mark the ones to actually delete. **Don't trust the filter blindly** — false positives in a delete pass are costly because the action is irreversible.

## Step 3 — Delete confirmed spam

```json
{
  "action": "posts:delete",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "postId": "abc123...32hex" }
}
```

Response:

```json
{
  "success": true,
  "postId": "abc123..."
}
```

Loop the deletions. The actor serializes internally to respect Skool's write rate limit (~25 writes/min).

## Step 4 — (Optional) Notify the author before deleting

For borderline cases, a quick DM ("Hey, this post got flagged by our community guidelines — moving it. If you think this was wrong, reply and we'll discuss") preserves the relationship. Skool's DM action isn't yet wrapped in the actor — for now, DM manually for borderline cases and reserve bulk delete for obvious spam.

## Production gotchas

- **`posts:delete` is irreversible.** There's no soft-delete or trash bin in Skool. Once deleted, the post + all its comments are gone. **Never automate this without a review step.**
- **Members can only delete their own posts.** If you call `posts:delete` for someone else's post and you're not admin/owner, you get `403 Forbidden`.
- **Deleting a pinned post un-pins it AND removes it.** If you wanted to demote a stale pinned announcement, use [`posts:unpin`](../docs/posts.md#postsunpin) instead.
- **Deleting a post nukes the comment thread.** A spam post with a long legitimate side-discussion: consider editing the title + locking instead of deleting. Skool doesn't expose lock/unlock yet — manual UI for now.
- **No bulk endpoint.** Skool requires one `posts:delete` call per post. The actor handles the loop; just don't expect a `posts:batchDelete` shortcut.
- **The deletion is visible in member notifications** if the author had subscribers. Some members will notice "X's post was removed" — be prepared to explain if asked.

## When this saves you the most time

- **Weekly housekeeping** in an active community (~5-15 spam posts/week to clean)
- **Onboarding a new community manager** — running this together once teaches the pattern
- **Post-launch surge cleanup** — after a viral moment, a percentage of new joins will drop low-effort posts in the first week

## See also

- [Posts API reference](../docs/posts.md) — `posts:delete` field-by-field
- [Recipe: Keyword monitoring auto-replies](keyword-monitoring-replies.md) — the *reply* path for borderline posts (instead of delete)
- [Recipe: Auto-approve members with AI screening](auto-approve-members-n8n.md) — the prevention path (filter at the front door)

---

## Use this in production — no setup

The hardest part of building Skool automation isn't the API logic — it's the auth (cookies expire every ~3.5 days, WAF token rotation, weekly Skool buildId changes). The **[Skool All-in-One API actor on Apify](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=spam-cleanup-posts-delete&fpr=cristian)** handles all of that.

- Pay-per-event pricing (~$1.50/mo for typical communities)
- `posts:filter` + `posts:delete` wrapped behind one JSON-over-HTTP surface
- Built by a solo community admin who actually has to keep their own feed clean every week

[**→ Open the actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=spam-cleanup-posts-delete&fpr=cristian)

*New to Skool? [Launch your community here](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*
*Need an n8n instance? [Get started free](https://n8n.partnerlinks.io/wpqwwllhiznx) — the workflow tool we use throughout these recipes.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "HowTo",
  "name": "Auto-detect and delete Skool spam posts",
  "description": "Find low-signal or spam posts (off-topic, promo, bot drops) and delete them in bulk via posts:delete, with a recommended human-in-the-loop review gate.",
  "totalTime": "PT5M",
  "tool": [
    {"@type": "HowToTool", "name": "Apify"},
    {"@type": "HowToTool", "name": "Skool admin cookies"}
  ],
  "step": [
    {"@type": "HowToStep", "name": "Filter spam candidates", "text": "Surface candidates by keyword with posts:filter, by low engagement with posts:list plus a client-side filter for zero comments and over 48h old, and by new-author link-dropping patterns."},
    {"@type": "HowToStep", "name": "Review the candidate list", "text": "Print each candidate (author, title, body preview, join date) to a terminal, sheet or Telegram thread and manually mark the ones to delete."},
    {"@type": "HowToStep", "name": "Delete confirmed spam", "text": "Loop posts:delete for the confirmed posts. The action is irreversible, so only delete after review."},
    {"@type": "HowToStep", "name": "Notify borderline authors", "text": "For borderline cases, DM the author before removing to preserve the relationship, reserving bulk delete for obvious spam."}
  ]
}
</script>
