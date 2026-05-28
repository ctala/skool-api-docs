---
title: "Auto-post Skool event reminders to the feed (24h + 1h before)"
description: "Pull upcoming Skool events and post timed reminders to the community feed automatically. The cron-driven flow that keeps event attendance from cratering."
slug: /recipes/event-reminders-to-feed
type: recipe
funnel: A
section: Recipes
last_updated: 2026-05-28
render_with_liquid: false
---

# Auto-post Skool event reminders to the feed

Skool sends an email when you create an event, and another email at the start. Email open rates being what they are, that's not enough to keep attendance up. The **feed** is where the active members live — a timely reminder post 24h + 1h before an event is the lever that consistently doubles attendance.

This recipe is the cron-driven flow used in production to announce events for [Cágala, Aprende, Repite](https://www.skool.com/cagala-aprende-repite)'s weekly Cafecito, Workshops, and Posting Party. Same pattern works for any recurring event.

## Quick reference (TL;DR for agents)

| | |
|---|---|
| **Goal** | Auto-post timed reminders to the feed for upcoming Skool events |
| **Stack** | n8n / Python + cron (hourly trigger) |
| **Actions used** | [`events:upcoming`](../docs/events.md#eventsupcoming) → [`posts:create`](../docs/posts.md#postscreate) |
| **Setup time** | ~15 min (workflow + first event) |
| **Ongoing cost** | `$0.02` per reminder (2 reminders per event = ~$0.04/event) |
| **Cadence** | 24h + 1h before each event |
| **Key gotcha** | Idempotency — don't double-post if the cron runs twice in the same window |

## Prerequisites

- Apify token ([sign up free](https://console.apify.com/sign-up?fpr=cristian))
- Skool admin cookies (see [Authentication](../docs/authentication.md))
- At least one published Skool event (created via the Skool admin UI — event creation via API is not yet exposed)
- A scheduler (n8n cron, GitHub Actions cron, server crontab) running hourly

## How the timing logic works

The action `events:upcoming` returns events with their `startsAt` timestamp. Your cron runs hourly, and for each event you compute the delta:

```
now ≤ startsAt − 24h ≤ now + 1h  →  post the "tomorrow" reminder
now ≤ startsAt − 1h ≤ now + 1h   →  post the "in 1 hour" reminder
```

The 1-hour bucket size matches the cron cadence — each event hits each reminder slot exactly once. To prevent double-posting if the cron is re-triggered (network retry, manual run), de-dupe by event_id + reminder_type in a small state store (NocoDB row, a flat JSON file, anything).

## Step 1 — List upcoming events

```json
{
  "action": "events:upcoming",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "limit": 20 }
}
```

Returns events sorted by `startsAt` ascending. Each event includes `id`, `title`, `startsAt`, `endsAt`, `description`, `joinUrl` (Zoom/Meet/etc), and `attendeeCount`.

## Step 2 — Compute reminder timing

For each event, check if it falls in the 24h or 1h window relative to now:

```python
from datetime import datetime, timedelta, timezone

now = datetime.now(timezone.utc)
for event in events:
    starts_at = datetime.fromisoformat(event["startsAt"].replace("Z", "+00:00"))
    delta = starts_at - now
    if timedelta(hours=23) < delta <= timedelta(hours=24):
        post_reminder(event, kind="24h")
    elif timedelta(minutes=0) < delta <= timedelta(hours=1):
        post_reminder(event, kind="1h")
```

The window edges (`< 24h, ≤ 24h`) match a 1-hour cron precisely. If your cron is 30-minute, narrow the windows.

## Step 3 — Post the reminder to the feed

```json
{
  "action": "posts:create",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "title": "📅 Mañana: Cafecito Startup — 12:00 hrs",
    "content": "Mañana nos juntamos a hablar de... Trae tu pregunta, tu update, lo que estés trabajando. Link de Zoom en el evento: https://www.skool.com/your-community/calendar",
    "labelId": "announcements_label_id"
  }
}
```

| Field | Notes |
|---|---|
| `title` | Short, time-stamped. "📅 Mañana: ..." for 24h, "🔴 EN 1 HORA: ..." for the 1h. |
| `content` | Plain text. Include a link to the Skool calendar so members 1-click into the event detail page. |
| `labelId` | Tag the post with your "Anuncios" / "Announcements" category so it doesn't get lost in the feed. See [Categories of CAR feed](../docs/posts.md#labels). |

## Step 4 — De-dupe via your state store

After posting, write to your state store:

```python
# pseudo: prevent double-post
state[f"{event['id']}-{kind}"] = {"posted_at": now.isoformat(), "post_id": response["post"]["id"]}
```

On the next cron tick, skip if the key exists. The whole de-dupe layer is ~10 lines — don't over-engineer.

## Full workflow JSON (n8n)

The production version uses n8n with a Cron trigger every hour → HTTP Request to the actor (`events:upcoming`) → Function node to compute deltas → Switch (24h / 1h) → HTTP Request to actor (`posts:create`) → NocoDB upsert to de-dupe store.

The JSON is in the repo at [`n8n-templates/skool-events-to-whatsapp.json`](https://github.com/ctala/skool-api-docs/tree/main/n8n-templates) — it's the same logic adapted for WhatsApp/Telegram, swap the final node for `posts:create` to post to the Skool feed instead.

## Production gotchas

- **Idempotency is mandatory.** Without de-dupe, a transient network error in the middle of the cron will replay the whole loop on retry — posting two reminders for the same event. The de-dupe store doesn't have to be fancy; a flat JSON file is fine.
- **Time zones.** `startsAt` is UTC. Convert to your local TZ before formatting in the post title so members see "12:00 hrs Chile" not "16:00 UTC". `pytz` or JS `Intl.DateTimeFormat` does it cleanly.
- **`events:upcoming` returns only EVENTS, not Skool LIVE.** Live sessions (the green dot) are a separate concept and surface in a different endpoint — not yet wrapped in the actor.
- **`attendeeCount` is RSVPs, not actual attendance.** Don't use it as a proxy for "should I send reminder" — send for every event.
- **Posting too early (>24h out) clutters the feed.** Keep the windows tight. If you want a "next week" mention, do that manually in a weekly digest post, not via this cron.

## See also

- [Recipe: Automate Skool events (full flow)](automate-skool-events.md) — the WhatsApp/Telegram counterpart of this cron
- [Events API reference](../docs/events.md) — `events:list` + `events:upcoming` + params
- [Posts API reference](../docs/posts.md) — `posts:create` field-by-field

---

## Use this in production — no setup

The hardest part of building Skool automation isn't the API logic — it's the auth (cookies expire every ~3.5 days, WAF token rotation, weekly Skool buildId changes). The **[Skool All-in-One API actor on Apify](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=event-reminders-to-feed&fpr=cristian)** handles all of that.

- Pay-per-event pricing (~$1.50/mo for typical communities)
- `events:upcoming` and `posts:create` both wrapped in one consistent JSON-over-HTTP surface
- The 1-hour cron + 2 reminders per event runs reliably under the Apify free tier for most communities

[**→ Open the actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=event-reminders-to-feed&fpr=cristian)

*New to Skool? [Launch your community here](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*
*Need an n8n instance? [Get started free](https://n8n.partnerlinks.io/wpqwwllhiznx) — the workflow tool we use throughout these recipes.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "HowTo",
  "name": "Auto-post Skool event reminders to the feed",
  "description": "Auto-post 24h and 1h reminders to the Skool feed for every upcoming event. Cron-driven idempotent flow using events:upcoming + posts:create.",
  "totalTime": "PT15M",
  "tool": [{"@type": "HowToTool", "name": "Apify"}, {"@type": "HowToTool", "name": "n8n or any cron scheduler"}, {"@type": "HowToTool", "name": "Skool admin cookies"}],
  "step": [
    {"@type": "HowToStep", "name": "List upcoming events", "text": "Call events:upcoming to get the next N events with startsAt timestamps."},
    {"@type": "HowToStep", "name": "Compute timing", "text": "For each event, check if it falls in the 24h or 1h window relative to now (assumes hourly cron cadence)."},
    {"@type": "HowToStep", "name": "Post reminder + de-dupe", "text": "Call posts:create with a time-stamped title and category labelId. Write to a small state store to prevent double-posting on cron retry."}
  ]
}
</script>
