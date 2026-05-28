---
title: "Skool Webhook Integration — Trigger Workflows from Skool Events (2026)"
description: "Skool has no native webhooks. Use the Apify-hosted Skool API actor as a polling proxy — fire your webhook on new members, posts, comments. No official Skool API needed."
slug: /integrations/skool-webhook
type: integration
primary_keyword: "skool webhook"
search_volume_monthly: 10
funnel: A
playbook: integrations
last_updated: 2026-05-19
canonical: https://ctala.github.io/skool-api-docs/integrations/skool-webhook/
render_with_liquid: false
---


> **Quick reference (TL;DR for agents)**
> - **Does Skool have native webhooks?** Effectively no — Skool offers a few opaque webhook actions inside its Zapier/Make integrations but no general-purpose user-defined webhooks for events like "new member applied" or "new post created".
> - **The workaround:** poll the [Apify-hosted Skool API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-webhook&fpr=cristian) on a schedule (n8n / Make / cron / GitHub Action), diff against last state, fire your own webhook on new items.
> - **Latency:** poll interval defines the lag — typical setups poll every 1-5 minutes.
> - **Cost:** ~$0.005 per poll × N polls per day.

## Why Skool's "webhooks" aren't enough

Skool's Zapier/Make integration exposes a couple of trigger-style webhooks (new member, new post) but:

- You can't define custom webhook URLs Skool will POST to
- The available events are limited and undocumented
- Setting them up requires the Zapier/Make middleware (extra cost, extra latency)
- Webhooks are unreliable — Skool doesn't expose retry policy or signature verification

For production reliability, polling the Skool API yourself and emitting webhooks is the more honest pattern.

## Architecture — polling proxy

```
[Scheduler]                         [Apify actor]                      [Your webhook receiver]
   │                                      │                                   │
   ├── every 60s ──POST action────────────┤                                   │
   │   { posts:filter, since: last_seen } │                                   │
   │                                      ├──── api.skool.com ──── data       │
   │                                      │                                   │
   ◄────── new items ────────────────────┤                                   │
   │                                                                          │
   ├── for each new item ──HTTP POST your webhook ─────────────────────────►──┤
   │                                                                          │
   ├── update last_seen                                                       │
```

The "scheduler" can be n8n cron, Make schedule, a GitHub Action on cron, a Cloudflare Worker scheduled trigger, or a one-line Linux cron.

## Setup — 10 minutes

### 1. Decide your polling interval

- **1 minute** — most responsive, costs ~$200/year in Apify polls ($0.005 × 60 × 24 × 365). Good if Skool events are time-critical (e.g. handing off to Slack support).
- **5 minutes** — typical balance, ~$45/year.
- **15 minutes** — budget option, ~$15/year. Use this for "new member" events you'll handle within an hour anyway.

### 2. Pick the event to poll

| Event | Actor action | Filter |
|---|---|---|
| New member application | `members:pending` | All returned items are pending (poll, diff by `memberId`) |
| New member joined (approved) | `members:list` | Track `joinedAt` against last seen |
| New post in feed | `posts:list` or `posts:filter` | `since: last_poll_timestamp` |
| New comment on a specific post | direct `/posts/{postId}/comments` call | Track comment IDs seen |
| New comment in any post | poll `posts:list` then `posts:getComments` on hot threads | More expensive — only do this for high-priority threads |

### 3. n8n implementation (shortest path)

```
[Schedule Trigger — every 1 min]
        │
        ▼
[HTTP Request — POST Apify with posts:filter since={{$node["lastSeen"].json.timestamp}}]
        │
        ▼
[Function — diff against $workflow.staticData.seenPostIds; collect new items]
        │
        ▼
[Loop — for each new item]
        │
        ▼
[HTTP Request — POST your webhook URL with the item payload]
        │
        ▼
[Function — update lastSeen + seenPostIds in $workflow.staticData]
```

n8n's `$workflow.staticData` persists across runs — perfect for "last seen" state without a database.

### 4. Cron + curl implementation (no infrastructure)

```bash
#!/bin/bash
# /usr/local/bin/skool-webhook-poll.sh — runs every minute via cron

APIFY_TOKEN="..."
COOKIES="..."   # rotate via separate auth:login script every 3 days
GROUP="your-community"
WEBHOOK_URL="https://your-receiver.example.com/skool-events"
LAST_SEEN=$(cat /tmp/skool-last-seen 2>/dev/null || echo "2026-01-01T00:00:00Z")

POSTS=$(curl -s -X POST \
  "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=$APIFY_TOKEN&build=latest&timeout=30" \
  -H 'Content-Type: application/json' \
  -d "{
    \"action\": \"posts:filter\",
    \"cookies\": \"$COOKIES\",
    \"groupSlug\": \"$GROUP\",
    \"params\": {\"since\": \"$LAST_SEEN\", \"limit\": 50}
  }")

echo "$POSTS" | jq -c '.[] | .data.posts[]?' | while read post; do
  curl -s -X POST "$WEBHOOK_URL" -H 'Content-Type: application/json' -d "$post"
done

date -u +%Y-%m-%dT%H:%M:%SZ > /tmp/skool-last-seen
```

Cron: `* * * * * /usr/local/bin/skool-webhook-poll.sh >> /var/log/skool-webhook.log 2>&1`.

## Cookie rotation for unattended polling

Cookies expire every ~3.5 days. For unattended polling, your runner must auto-rotate:

1. Detect `errorCode: "WAF_EXPIRED"` in the response
2. Call `auth:login` with stored email/password
3. Update the stored cookies
4. Retry the failed action

This is critical for any production webhook setup. See [authentication docs](../docs/authentication.md).

## Production gotchas

- **First poll returns everything** — set `last_seen` to a recent timestamp on the first run so you don't replay the entire feed history to your webhook.
- **`since` is inclusive** — comparing `createdAt > since` server-side means you can miss items if Skool's clock skews. Use `>=` and dedupe by ID client-side.
- **Rate limit 25 writes/min** doesn't apply to reads, but Apify's per-actor concurrency does. Don't run two pollers against the same actor key.
- **Cookies expire = silent failure** if you don't branch on `WAF_EXPIRED`. Add monitoring.
- **Webhook signing** — Skool doesn't sign webhooks (because it's not generating them — you are). Add HMAC signing yourself before POSTing to downstream receivers if you care about authenticity.

## Related

- [Skool + n8n](skool-n8n.md)
- [Skool + Make.com](skool-make-com.md)
- [Skool + Python](skool-python.md)
- [Posts & Comments reference](../docs/posts.md)

---

## Get production-grade Skool webhooks today

[**→ Open the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-webhook&fpr=cristian)

Polling-based webhooks via one POST per check. Pay-per-event (~$1.50-$15/mo depending on polling frequency). Battle-tested in production.

*New to Skool? [Launch your community here](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day trial.*

<script type="application/ld+json">
{"@context":"https://schema.org","@type":"TechArticle","headline":"Skool Webhook Integration","datePublished":"2026-05-19","author":{"@type":"Person","name":"Cristian Tala"}}
</script>
