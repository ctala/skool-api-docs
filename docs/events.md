---
title: "Events — Skool API Reference"
description: "Read upcoming and past Skool events via the API. Power event reminder automations, attendance analytics, and external calendar sync."
slug: /docs/events
type: reference
section: Docs
last_updated: 2026-05-28
render_with_liquid: false
---

# Events

Read Skool community events programmatically — upcoming events for reminder automations, past events for attendance analytics, calendar sync to external systems.

> **Event creation is NOT yet exposed via API.** Today you create events through the Skool admin UI; the actor only handles reads + downstream automations triggered from events.

## Read actions

### `events:list` — all events (past + upcoming)

```json
{
  "action": "events:list",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "limit": 50,
    "from": "2026-01-01T00:00:00Z",
    "to": "2026-12-31T23:59:59Z"
  }
}
```

| Param | Default |
|---|---|
| `limit` | 20 |
| `from` | (no filter — returns all available) |
| `to` | (no filter) |

Response:

```json
{
  "success": true,
  "events": [
    {
      "id": "event_32hex",
      "title": "Cafecito Startup — Mayo 28",
      "description": "Weekly community chat with founders...",
      "startsAt": "2026-05-28T15:00:00Z",
      "endsAt": "2026-05-28T16:00:00Z",
      "joinUrl": "https://zoom.us/j/...",
      "attendeeCount": 23,
      "createdAt": "2026-05-21T10:00:00Z",
      "createdBy": "user_32hex"
    }
  ],
  "hasMore": false
}
```

Returns events sorted by `startsAt` descending (most recent first).

### `events:upcoming` — only future events

The convenience action for reminder automations — returns only events with `startsAt > now`.

```json
{
  "action": "events:upcoming",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "limit": 20 }
}
```

Response shape is identical to `events:list`. Sorted by `startsAt` **ascending** (next event first) — opposite of `events:list`.

## Common use cases

### Reminder automations

The most common downstream pattern: cron every hour → `events:upcoming` → for each event, check if it falls in the 24h or 1h window → `posts:create` to feed (or send via WhatsApp / Telegram / email).

See the full recipe: [Event reminders to feed (24h + 1h)](../recipes/event-reminders-to-feed.md).

### Calendar sync

Pull all upcoming events, format as iCal / Google Calendar batch import, sync to a shared calendar your team subscribes to. Useful for community managers running multiple Skool groups.

### Attendance analytics

`attendeeCount` is RSVPs, not actual attendance — Skool tracks who joined the call only for Zoom-integrated events (and even then, that count isn't exposed via API yet). For real attendance, the best proxy is `posts:filter --query "event_title"` after the event — members who post about it are the ones who actually showed.

## Common gotchas

### `attendeeCount` is RSVPs, not attendance

This trips everyone. The number is "who clicked Going on the event page", not "who actually joined the call". For a recurring event, RSVP/attendance ratio is typically 0.4-0.6. Don't quote `attendeeCount` as attendance in your community recap.

### Time zones

All timestamps are UTC. For posts in your feed, convert to your local TZ before formatting (`pytz`, `Intl.DateTimeFormat`, or whatever your stack supports).

### `events:list` may exclude very old events

Skool sometimes truncates `events:list` to the last ~90 days for performance. If you need historical data older than that, save snapshots periodically in your own DB.

### No `events:create`, `events:update`, `events:delete` yet

The write surface for events is not yet exposed via the actor. Event creation/editing is admin UI only as of v0.3.27. If you need this, request it via [GitHub issues](https://github.com/ctala/skool-api-docs/issues).

### Skool Live ≠ Events

Skool "Live" (the green dot when admins go live) is a separate concept and isn't returned by `events:list` / `events:upcoming`. Different endpoint, not yet wrapped.

## Recipes

- [**Event reminders to feed (24h + 1h)**](../recipes/event-reminders-to-feed.md) — cron-driven flow using `events:upcoming` + `posts:create`
- [**Automate Skool events (Telegram/WhatsApp)**](../recipes/automate-skool-events.md) — the messaging-channel counterpart of the same flow

## See also

- [Posts](posts.md) — `posts:create` for the reminder publishing step
- [Groups](groups.md) — group-level settings
- [Authentication](authentication.md) — cookies, WAF token rotation

---

## Use this in production — no setup

The hardest part of building Skool automation isn't the API logic — it's the auth (cookies expire every ~3.5 days, WAF token rotation, weekly Skool buildId changes). The **[Skool All-in-One API actor on Apify](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=docs&utm_campaign=events&fpr=cristian)** handles all of that.

- Pay-per-event pricing (~$1.50/mo for typical communities)
- `events:list` + `events:upcoming` both wrapped in one consistent JSON-over-HTTP surface
- Cookie/WAF rotation handled internally — your reminder cron doesn't break weekly

[**→ Open the actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=docs&utm_campaign=events&fpr=cristian)

*New to Skool? [Launch your community here](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*
*Need an n8n instance? [Get started free](https://n8n.partnerlinks.io/wpqwwllhiznx) — the workflow tool we use throughout these recipes.*
