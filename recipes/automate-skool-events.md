---
title: "Automate Skool Community Event Announcements"
description: "Auto-announce upcoming Skool calendar events to your feed, Slack, Telegram, or WhatsApp. Uses events:upcoming + posts:create. Reduces no-shows + drives attendance."
slug: /recipes/automate-skool-events
type: recipe
primary_keyword: "skool calendar automation"
search_volume_monthly: null
funnel: A
section: Recipes
last_updated: 2026-05-19
render_with_liquid: false
---

> **Quick reference (TL;DR for agents)**
> - **Goal:** Auto-announce upcoming Skool events (community calls, workshops, masterminds) to your feed, Telegram channel, Slack workspace, or WhatsApp broadcast — 24h and 1h before each event.
> - **Stack:** n8n / Python cron + Apify Skool API actor + your messaging provider.
> - **Actor actions used:** `auth:login` → `events:upcoming` → `posts:create` (and/or messaging webhook).
> - **Setup time:** ~20 min.
> - **Ongoing cost:** ~$0.02 per announcement run (one `events:upcoming` read + one `posts:create` write).

## What this recipe does

Skool's calendar feature is great, but **members don't check the calendar tab** — they check the feed. If you schedule a weekly community call and only put it in the calendar, you'll see 30-50% lower attendance vs. announcing it in the feed every week.

This recipe runs on a schedule (e.g. every 6 hours), fetches upcoming events from `events:upcoming`, and:

1. Posts a reminder in the community feed 24h before each event
2. Sends a Telegram / Slack / WhatsApp ping 1h before (optional)
3. Logs sent reminders to avoid duplicates

Used in production for weekly Cafecito calls — bumped attendance from ~12 to ~25 on a 500-member community.

## Prerequisites

- Apify token + Skool admin cookies
- A scheduler (n8n cron, GitHub Actions, Cloud Run scheduled job, or a Linux crontab)
- (Optional) Telegram bot / Slack incoming webhook / WhatsApp Cloud API for off-platform notifications
- A small KV store (Apify dataset, Redis, even a JSON file) to track "already announced" event IDs

## Step 1 — Get upcoming events

The `events:upcoming` action returns events sorted ascending. Each item has `nextOccurrence`, `timezone`, `occurrenceId`, and the event's title + description.

```json
{
  "action": "events:upcoming",
  "cookies": "{COOKIES}",
  "groupSlug": "your-community",
  "params": { "limit": 10 }
}
```

Response shape (simplified):

```json
{
  "success": true,
  "data": {
    "events": [
      {
        "id": "abc123...",
        "occurrenceId": "abc123:1716220800",
        "name": "weekly-cafecito",
        "title": "Cafecito Startup — Wed 7pm",
        "description": "Weekly community call. Bring your stuck...",
        "nextOccurrence": "2026-05-21T22:00:00Z",
        "timezone": "America/Santiago",
        "url": "https://meet.google.com/abc-defg-hij"
      }
    ]
  }
}
```

## Step 2 — Filter to "events in the next 24h or 1h"

In your scheduler (n8n Function node, Python script, etc.):

```python
from datetime import datetime, timezone, timedelta

now = datetime.now(timezone.utc)
window_24h = now + timedelta(hours=24)
window_1h = now + timedelta(hours=1)

for ev in upcoming_events:
    occ = datetime.fromisoformat(ev["nextOccurrence"].replace("Z", "+00:00"))
    delta = occ - now

    if timedelta(hours=0) < delta <= timedelta(hours=1):
        send_1h_ping(ev)
    elif timedelta(hours=23) < delta <= timedelta(hours=25):
        post_24h_reminder(ev)
```

The `delta` bounds (23-25h for the 24h window, 0-1h for the 1h ping) give you slack if your scheduler runs every 6h or every hour and an event falls on the boundary.

## Step 3 — Dedupe (avoid double announcements)

Track which `occurrenceId`s you've already announced. Simplest implementations:

- **n8n:** `$workflow.staticData.announcedOccurrenceIds = [...]`
- **Python cron:** read/write a JSON file (`/tmp/skool-announced.json`)
- **Apify integration:** push to the actor's default key-value store

```python
import json
from pathlib import Path

state_file = Path("/tmp/skool-announced.json")
state = json.loads(state_file.read_text()) if state_file.exists() else {"announced": []}

def already_announced(occurrence_id, window):
    key = f"{occurrence_id}:{window}"
    return key in state["announced"]

def mark_announced(occurrence_id, window):
    key = f"{occurrence_id}:{window}"
    state["announced"].append(key)
    state_file.write_text(json.dumps(state))
```

Without dedupe, an hourly scheduler running through a 1h window will announce the same event multiple times.

## Step 4 — Post the 24h reminder to the feed

```python
import requests, os

def post_24h_reminder(ev):
    if already_announced(ev["occurrenceId"], "24h"):
        return

    when_local = format_local_time(ev["nextOccurrence"], ev.get("timezone"))
    body = (
        f"⏰ Recordatorio: {ev['title']} mañana — {when_local}.\n\n"
        f"{ev.get('description', '')[:200]}\n\n"
        f"Link directo a la sala: {ev.get('url', 'ver calendario')}"
    )

    payload = {
        "action": "posts:create",
        "cookies": os.environ["SKOOL_COOKIES"],
        "groupSlug": os.environ["SKOOL_GROUP_SLUG"],
        "params": {
            "title": f"Recordatorio: {ev['title'][:40]}",
            "content": body,
        }
    }
    r = requests.post(
        f"https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token={os.environ['APIFY_TOKEN']}&build=latest&timeout=60",
        json=payload, timeout=90
    )
    result = r.json()[0]
    if result.get("success"):
        mark_announced(ev["occurrenceId"], "24h")
```

## Step 5 — Send the 1h ping to Telegram / Slack

For off-platform pings (most members get Telegram/Slack notifications faster than Skool push):

```python
def send_1h_ping(ev):
    if already_announced(ev["occurrenceId"], "1h"):
        return

    text = f"🔴 EN VIVO EN 1 HORA: {ev['title']}\nLink: {ev.get('url', '')}"

    # Telegram
    requests.post(
        f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage",
        json={"chat_id": TELEGRAM_CHAT_ID, "text": text}
    )

    # Slack
    requests.post(SLACK_WEBHOOK_URL, json={"text": text})

    mark_announced(ev["occurrenceId"], "1h")
```

Combine with the WhatsApp Cloud API for full coverage if you have a VIP group there too.

## Step 6 — Schedule the runner

### GitHub Actions (free for personal use)

`.github/workflows/skool-events.yml`:

```yaml
name: Skool event announcer
on:
  schedule:
    - cron: "0 */6 * * *"   # every 6 hours
  workflow_dispatch:

jobs:
  run:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: {python-version: "3.11"}
      - run: pip install requests
      - run: python events_bot.py
        env:
          APIFY_TOKEN: # secrets.APIFY_TOKEN
          SKOOL_COOKIES: # secrets.SKOOL_COOKIES
          SKOOL_GROUP_SLUG: # secrets.SKOOL_GROUP_SLUG
          TELEGRAM_TOKEN: # secrets.TELEGRAM_TOKEN
          TELEGRAM_CHAT_ID: # secrets.TELEGRAM_CHAT_ID
```

### Linux cron

```bash
# every hour
0 * * * * cd /opt/skool-events && /usr/bin/python3 events_bot.py >> bot.log 2>&1
```

## Production gotchas

- **`nextOccurrence` is UTC.** Don't compare against `datetime.now()` (local time). Use `datetime.now(timezone.utc)`.
- **Recurring events**: the same event ID will show new `occurrenceId`s every week. Your dedupe key MUST be `occurrenceId`, not `eventId`, otherwise you'll only announce the first occurrence then go silent.
- **Cookie rotation**: cookies expire ~every 3.5 days. Branch on `errorCode == "WAF_EXPIRED"` and call `auth:login` to refresh. Same pattern as [other recipes](reply-unanswered-posts.md).
- **Posting frequency**: don't post a reminder more than 24h ahead — members forget. Don't post less than 30 min before — too late to act. The 24h + 1h pattern hits both windows.
- **Title length**: Skool caps post titles at ~80 chars. Use `ev['title'][:60]` to avoid `TITLE_TOO_LONG` errors.
- **Skool feed rate limit**: ~25 writes/min. Not an issue at 1 reminder every few hours, but if you ever batch-announce 10+ events in a single run, sleep between writes.

## Full Python script

<details>
<summary>events_bot.py — single-file implementation</summary>

```python
#!/usr/bin/env python3
"""Skool event announcer — runs on a schedule, posts 24h + 1h reminders."""
import os, json, requests
from datetime import datetime, timezone, timedelta
from pathlib import Path

APIFY_TOKEN = os.environ["APIFY_TOKEN"]
COOKIES = os.environ["SKOOL_COOKIES"]
GROUP = os.environ["SKOOL_GROUP_SLUG"]
TG_TOKEN = os.environ.get("TELEGRAM_TOKEN")
TG_CHAT = os.environ.get("TELEGRAM_CHAT_ID")

state_file = Path("/tmp/skool-announced.json")
state = json.loads(state_file.read_text()) if state_file.exists() else {"announced": []}

def actor(action, params):
    r = requests.post(
        f"https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token={APIFY_TOKEN}&build=latest&timeout=60",
        json={"action": action, "cookies": COOKIES, "groupSlug": GROUP, "params": params},
        timeout=90
    )
    return r.json()[0]

def announced(occ_id, win): return f"{occ_id}:{win}" in state["announced"]
def mark(occ_id, win):
    state["announced"].append(f"{occ_id}:{win}")
    state_file.write_text(json.dumps(state))

events = actor("events:upcoming", {"limit": 10}).get("data", {}).get("events", [])
now = datetime.now(timezone.utc)

for ev in events:
    occ = datetime.fromisoformat(ev["nextOccurrence"].replace("Z", "+00:00"))
    delta_h = (occ - now).total_seconds() / 3600

    if 0 < delta_h <= 1 and not announced(ev["occurrenceId"], "1h"):
        if TG_TOKEN:
            requests.post(f"https://api.telegram.org/bot{TG_TOKEN}/sendMessage",
                json={"chat_id": TG_CHAT, "text": f"🔴 EN VIVO EN 1H: {ev['title']}\n{ev.get('url','')}"})
        mark(ev["occurrenceId"], "1h")

    elif 23 < delta_h <= 25 and not announced(ev["occurrenceId"], "24h"):
        body = f"⏰ Mañana: {ev['title']}\n\n{ev.get('description','')[:200]}\n\nLink: {ev.get('url', 'ver calendario')}"
        res = actor("posts:create", {
            "title": f"Recordatorio: {ev['title'][:40]}",
            "content": body
        })
        if res.get("success"):
            mark(ev["occurrenceId"], "24h")

print(f"Processed {len(events)} upcoming events. State: {len(state['announced'])} announcements logged.")
```

</details>

## See also

- [Actions reference](../docs/actions.md) — `events:list`, `events:upcoming`, `posts:create`
- [Reply to unanswered posts](reply-unanswered-posts.md) — companion recipe with same scheduler pattern
- [Skool + n8n](../integrations/skool-n8n.md) — how to wire this into n8n if you prefer no-code

---

## Use it in production today

[**→ Open the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=automate-skool-events&fpr=cristian)

Pay-per-event (~$0.02 per announcement). Battle-tested in production.

*No Skool community yet? [Launch one in 10 minutes](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*
*Need an n8n instance? [Get started free](https://n8n.partnerlinks.io/wpqwwllhiznx) — the workflow tool we use throughout these recipes.*

<script type="application/ld+json">
{"@context":"https://schema.org","@type":"HowTo","name":"Automate Skool Community Event Announcements","datePublished":"2026-05-19","author":{"@type":"Person","name":"Cristian Tala"}}
</script>
