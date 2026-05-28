---
title: "Discover your Skool community's label IDs (for category-filtered automations)"
description: "Pull your Skool group's category labelIds programmatically — needed to filter posts by category, create labelled posts, or audit your category strategy."
slug: /recipes/discover-skool-label-ids
type: recipe
funnel: A
section: Recipes
last_updated: 2026-05-28
render_with_liquid: false
---

# Discover your Skool community's label IDs

Every Skool community has **categories** (labels) for posts — "Anuncios", "General", "Reflexiones", "Recursos", whatever you set up. Each category has an internal `labelId` that the Skool admin UI never shows you. To filter posts by category programmatically or to create a post tagged with a specific label, you need that `labelId`.

This recipe is the **discovery flow** — pull your group's label map once, save it, and use the IDs in your downstream automations. Takes ~30 seconds, eliminates a friction point every category-aware recipe runs into.

## Quick reference (TL;DR for agents)

| | |
|---|---|
| **Goal** | Map your Skool community's category names → `labelId` for use in `posts:filter` / `posts:create` |
| **Stack** | Any HTTP client + the Apify-hosted actor |
| **Actions used** | [`groups:get`](../docs/groups.md#groupsget) → optional: [`posts:filter`](../docs/posts.md#postsfilter) to verify |
| **Setup time** | ~3 min |
| **Ongoing cost** | `$0.01` per `groups:get` call |
| **Frequency** | Once per community, then cache. Re-run only when you add/rename categories |

## Prerequisites

- Apify token ([sign up free](https://console.apify.com/sign-up?fpr=cristian))
- Skool admin cookies (see [Authentication](../docs/authentication.md))
- You're an admin/owner (label info is in the admin payload)

## Step 1 — Call `groups:get`

```json
{
  "action": "groups:get",
  "cookies": "...",
  "groupSlug": "your-community"
}
```

Response includes the full group config. The labels live under `metadata.post_categories` (Skool internal field name — varies slightly by group version, see gotchas):

```json
{
  "success": true,
  "group": {
    "id": "group_32hex",
    "name": "Your Community",
    "slug": "your-community",
    "metadata": {
      "post_categories": [
        { "id": "label_abc123", "name": "📣 Anuncios", "color": "#FF6B6B", "order": 1 },
        { "id": "label_def456", "name": "💬 General", "color": "#4ECDC4", "order": 2 },
        { "id": "label_ghi789", "name": "🧠 Reflexiones", "color": "#9D4EDD", "order": 3 },
        { "id": "label_jkl012", "name": "🛠 Recursos", "color": "#06D6A0", "order": 4 }
      ],
      "...": "..."
    }
  }
}
```

## Step 2 — Save the map

Pull the labels into a flat name→ID dict and save it (env vars, a small JSON file, your secrets store — wherever your automations read config from):

```python
labels = {cat["name"]: cat["id"] for cat in response["group"]["metadata"]["post_categories"]}
# {'📣 Anuncios': 'label_abc123', '💬 General': 'label_def456', ...}
```

Or for env vars:

```bash
SKOOL_LABEL_ANUNCIOS=label_abc123
SKOOL_LABEL_GENERAL=label_def456
SKOOL_LABEL_REFLEXIONES=label_ghi789
SKOOL_LABEL_RECURSOS=label_jkl012
```

## Step 3 — Verify with `posts:filter`

Confirm a labelId resolves to the expected posts:

```json
{
  "action": "posts:filter",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "labelId": "label_abc123",
    "limit": 10
  }
}
```

You should get the most recent 10 posts tagged "Anuncios". If you get unrelated posts, the labelId mapping is wrong — re-check step 1.

## Step 4 — Use in downstream automations

Once the map exists, every category-aware recipe gets simpler:

**Post a reminder tagged "Anuncios":**
```json
{
  "action": "posts:create",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "title": "📅 Mañana: Cafecito Startup",
    "content": "...",
    "labelId": "label_abc123"
  }
}
```

**Audit which categories underperform:**
Loop `posts:filter` per labelId → count comments/likes per category → see which ones get engagement vs. which are dead.

**Migrate posts to a new category:**
List all posts in old labelId → `posts:update` with new labelId.

## Production gotchas

- **`metadata` shape varies slightly by Skool version.** The field is usually `metadata.post_categories` but some older groups have it under `metadata.labels` or `categories`. If your `groups:get` response is missing `post_categories`, dump the full `metadata` and search for the array — it's there under some name.
- **Label colors are advisory only.** Skool's UI uses them for the chip background; they're not enforceable via the API.
- **`order` is the display order, not the ID.** Don't sort labels by `id` (which is opaque hex) — use `order` if you want UI-matching ordering.
- **Renaming a label in the Skool admin keeps the labelId.** So your saved map keeps working even if you rename "Anuncios" → "📣 Announcements". Adding a new category creates a new labelId; you have to re-pull.
- **Skool tracks ~8-12 labels per group as the typical UI limit.** If you have more, some won't show in the filter dropdown but they're still queryable via API.
- **No `groups:setLabels` action yet.** Creating / editing categories is admin UI only as of v0.3.27. You can read them but not write.

## See also

- [Groups API reference](../docs/groups.md) — `groups:get` + related actions
- [Posts API reference](../docs/posts.md) — `posts:filter` + `posts:create` with `labelId`
- [Recipe: Event reminders to feed](event-reminders-to-feed.md) — uses `labelId` to tag the reminder post

---

## Use this in production — no setup

The hardest part of building Skool automation isn't the API logic — it's the auth (cookies expire every ~3.5 days, WAF token rotation, weekly Skool buildId changes). The **[Skool All-in-One API actor on Apify](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=discover-skool-label-ids&fpr=cristian)** handles all of that.

- Pay-per-event pricing (~$1.50/mo for typical communities)
- `groups:get` returns the full label map in one call
- Built by a solo community admin — discovering your own labelIds shouldn't be the hard part of your automation

[**→ Open the actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=discover-skool-label-ids&fpr=cristian)

*New to Skool? [Launch your community here](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*
