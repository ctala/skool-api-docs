---
title: "Edit published Skool posts via API (title, content, labels)"
description: "Update a published Skool post's title, content, or category label via the API. Includes the silent-fail gotcha that costs everyone a debugging session and the read-then-write fix."
slug: /recipes/update-published-posts
type: recipe
funnel: A
section: Recipes
last_updated: 2026-05-28
render_with_liquid: false
---

# Edit published Skool posts via API

Need to fix a typo in a pinned post, swap a stale link across 20 announcements, or update the title of an evergreen feed post after a rebrand? The Skool UI lets you edit one post at a time. The API does the same write, scriptable — so you can run a corrections pass over hundreds of posts in one go.

The catch: the `posts:update` action has one silent-fail gotcha that wasted half a day of debugging when we first hit it. This recipe shows the canonical shape and the **read-then-write + verify-fetch** pattern that makes updates reliable.

## Quick reference (TL;DR for agents)

| | |
|---|---|
| **Goal** | Update title, content, or label of an existing Skool post |
| **Stack** | Any HTTP client + the Apify-hosted actor |
| **Actions used** | [`posts:get`](../docs/posts.md#postsget) → [`posts:update`](../docs/posts.md#postsupdate) → `posts:get` (verify) |
| **Setup time** | ~5 min |
| **Ongoing cost** | `$0.01 × N` posts updated |
| **Key gotcha** | Body MUST be **flat** (no `metadata` wrapper) or Skool returns 200 OK and silently ignores the update |
| **Mandatory pattern** | write + verify-fetch — never trust the 200 |

## Prerequisites

- Apify token ([get one](https://console.apify.com/sign-up?fpr=cristian))
- Skool admin cookies for the community (see [Authentication](../docs/authentication.md))
- The `postId` of each post you want to edit (32-char hex; visible in the URL as `?p={shortId}` — use `posts:filter` to map shortIds to full postIds)

## The non-obvious thing about `posts:update`

There are two body shapes that LOOK valid to a developer reading the network tab, but only one actually works:

```json
// ❌ THIS GETS 200 OK BUT THE UPDATE IS SILENTLY IGNORED
{
  "post_type": "generic",
  "group_id": "...",
  "metadata": {
    "title": "New title",
    "content": "New body"
  }
}

// ✅ THIS WORKS — flat body, no wrapper
{
  "title": "New title",
  "content": "New body",
  "attachments": "",
  "labels": "existing_label_id_or_empty",
  "video_links": "",
  "video_ids": []
}
```

We caught this by capturing the Skool admin UI's own update call with [API Reverse Engineer](https://chromewebstore.google.com/detail/dhpkbbfammoldcjhnngopbipkfmlpnej) — the UI sends the flat shape, and that's the only one Skool actually persists. The `metadata`-wrapped shape returns a clean `200 OK` response but the post in the database doesn't change.

The actor (`posts:update`) sends the correct flat shape internally. You only see this gotcha if you're calling the Skool API directly without the wrapper.

## Step 1 — Read the current post (to preserve `labels`)

If the post has a category label assigned, Skool requires `labels` in the update body or returns `400 "one or more labels required"`. Always read first:

```json
{
  "action": "posts:get",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "postId": "abc123...32hex" }
}
```

Save `labelId` (or `metadata.labels`) for the update call. If the post has no label, this can be empty.

## Step 2 — Update

```json
{
  "action": "posts:update",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "postId": "abc123...32hex",
    "title": "New title here",
    "content": "New body content as plain text. Mentions use [@Name](obj://user/{userId}) syntax.",
    "labels": "preserve_the_labelId_from_step_1"
  }
}
```

Field rules:

| Field | Rules |
|---|---|
| `title` | String. Empty string clears the title. |
| `content` | **Plain text only.** No TipTap, no Markdown — posts use raw text. Linebreaks are `\n`. |
| `labels` | Pass the existing `labelId` to preserve, or empty string if post had none. **Required if post had a label.** |
| `video_ids` | Must be array `[]`, never string `""` — passing string returns `500`. |

## Step 3 — Verify (never trust the 200)

```json
{ "action": "posts:get", "cookies": "...", "groupSlug": "your-community", "params": { "postId": "..." } }
```

Assert that `title` and `content` match what you sent. **This step is non-negotiable.** Skool's write endpoints have a documented history of returning success while silently no-op'ing — the only proof an update actually applied is a read-back showing the new value.

If verify fails: most likely you sent the wrapped `metadata` shape (you're calling the API directly, not the actor) or you missed `labels` for a labelled post.

## Production patterns

**Bulk find-and-replace across the feed.** List all posts containing a stale URL, run the swap, verify each.

```bash
# pseudo-flow
posts:filter --query "old-url.com" → for each: posts:get → posts:update (replace string) → posts:get (verify)
```

**Edit a pinned announcement.** Pinned posts in the feed get the most eyeballs. The API lets you update them without unpinning (avoiding the "new post" notification spam that re-pinning triggers).

**Correct typos in onboarding pinned threads.** The "Start here" post in [Cágala, Aprende, Repite](https://www.skool.com/cagala-aprende-repite)'s feed is updated this way when steps change — no notification fired, content updates in place.

## Production gotchas

- **The silent-fail gotcha (above).** Wrapped body → 200 OK → no change in DB. The actor handles this. If you're hitting Skool directly, copy the flat shape exactly.
- **`labels` is required if the post had one.** Read first, preserve, write. Otherwise `400`.
- **`video_ids: ""` (string) → 500.** Must be `[]` (array). The actor enforces this.
- **`parseRawPost` skool-js bug**: the library maps `p.labelId` (camelCase) but Skool returns `label_id` (snake_case). If you're using skool-js directly, fetch the raw response and read `label_id` or `metadata.labels` manually. The actor's `posts:update` already handles this.
- **Comments are preserved on update.** Editing a post doesn't wipe its comment thread.
- **No mention re-notification.** Adding a `[@Name]` mention in an edit does NOT trigger a notification (Skool only fires the first time the mention appears).

## See also

- [Posts API reference](../docs/posts.md) — every post action with params and gotchas
- [Recipe: Reply to unanswered posts](reply-unanswered-posts.md) — complementary write-path for posts
- [Posts and the silent-fail pattern](../docs/error-handling.md) — why write+verify-fetch is the rule for everything

---

## Use this in production — no setup

The hardest part of building Skool automation isn't the API logic — it's the auth (cookies expire every ~3.5 days, WAF token rotation, weekly Skool buildId changes). The **[Skool All-in-One API actor on Apify](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=update-published-posts&fpr=cristian)** handles all of that — including the flat-body shape for `posts:update`.

- Pay-per-event pricing (~$1.50/mo for typical communities)
- One JSON POST per action — works from any HTTP client
- The silent-fail wrapper bug is wrapped inside the action — you get the right shape by default

[**→ Open the actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=update-published-posts&fpr=cristian)

*New to Skool? [Launch your community here](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "HowTo",
  "name": "Edit published Skool posts via API",
  "description": "Update a published Skool post's title, content, or category label via the API. Includes the silent-fail gotcha and the read-then-write fix.",
  "totalTime": "PT5M",
  "tool": [
    {"@type": "HowToTool", "name": "Apify"},
    {"@type": "HowToTool", "name": "Skool admin cookies"}
  ],
  "step": [
    {"@type": "HowToStep", "name": "Read current post", "text": "Call posts:get to preserve labelId — required if the post has a category label."},
    {"@type": "HowToStep", "name": "Update with flat body", "text": "Call posts:update with title/content/labels in a flat body. The actor sends the correct shape — calling Skool directly with metadata wrapper silently ignores the update."},
    {"@type": "HowToStep", "name": "Verify with read-back", "text": "Call posts:get again and assert title+content match. Never trust the 200 — Skool can return success while no-op'ing silently."}
  ]
}
</script>
