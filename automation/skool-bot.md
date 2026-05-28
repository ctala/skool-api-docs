---
title: "Skool Bot — Build a Bot for Your Skool Community (2026)"
description: "Build a Skool bot that posts, replies, approves members, runs analytics. No SDK — one HTTP POST per action via the Apify Skool API actor."
slug: /automation/skool-bot
type: automation
primary_keyword: "skool bot"
search_volume_monthly: 10
funnel: A
playbook: automation
last_updated: 2026-05-19
canonical: https://ctala.github.io/skool-api-docs/automation/skool-bot/
render_with_liquid: false
---


> **TL;DR.** A "Skool bot" is any program that operates a Skool community programmatically — posting, replying, approving members, generating reports. There's no Skool bot platform like Discord's. Use the [Apify-hosted Skool API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=automation&utm_campaign=skool-bot&fpr=cristian), point one HTTP POST per action at it, deploy your bot wherever you deploy any script (cron, GitHub Actions, Cloud Run, Lambda, Railway, Fly.io).

## What kind of bot do you want to build?

| Bot type | Description | Recipe |
|---|---|---|
| **Auto-approver** | Screen applicants with LLM, approve good fits, surface borderline ones | [Auto-approve members](../recipes/auto-approve-members-n8n.md) |
| **Reply bot** | Reply to unanswered posts within X hours, with human approval | [Reply to unanswered posts](../recipes/reply-unanswered-posts.md) |
| **Welcome bot** | Personalized DMs + first-post invitation | [Auto DM new members](../recipes/auto-dm-new-members.md) |
| **Daily standup bot** | Auto-post a daily "what are you shipping today" thread | [Newsletter to Skool](../recipes/newsletter-to-skool-post.md) (similar pattern) |
| **Analytics bot** | Daily / weekly engagement summary in Slack/Telegram | Custom — pattern below |
| **Course publisher bot** | Watch a Git repo, push course updates to Skool when markdown changes | [Publish course from markdown](../recipes/publish-course-from-markdown.md) |
| **Moderation bot** | Auto-flag/remove posts violating community rules | Custom — LLM filter + `posts:delete` |

## Minimal bot — 30 lines of Python

```python
#!/usr/bin/env python3
"""Simple Skool bot — posts a daily standup thread at 9am."""
import os, json, requests
from datetime import datetime

APIFY_TOKEN = os.environ["APIFY_TOKEN"]
COOKIES = os.environ["SKOOL_COOKIES"]
GROUP = os.environ["SKOOL_GROUP_SLUG"]

def actor(action: str, params: dict) -> dict:
    r = requests.post(
        f"https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token={APIFY_TOKEN}&build=latest&timeout=90",
        json={"action": action, "cookies": COOKIES, "groupSlug": GROUP, "params": params},
        timeout=120
    )
    data = r.json()
    return data[0] if isinstance(data, list) else data

today = datetime.now().strftime("%b %d")
result = actor("posts:create", {
    "title": f"Daily standup — {today}",
    "content": "What are you shipping today? Drop it in this thread.\n\nNo bullet points needed — one sentence is fine. The point is the public commitment."
})
print(json.dumps(result, indent=2))
```

Deploy via `cron`, GitHub Actions, or any scheduler. Done.

## Analytics bot example

```python
def daily_digest():
    posts = actor("posts:filter", {"since": "{{ now - 24h }}", "limit": 50})
    members = actor("members:list", {"limit": 1})  # we just want the total
    pending = actor("members:pending", {})

    summary = {
        "total_members": members["data"]["total"],
        "new_posts_24h": len(posts["data"]["posts"]),
        "pending_applicants": len(pending["data"]["members"]),
        "top_post": max(posts["data"]["posts"], key=lambda p: p.get("commentsCount", 0)) if posts["data"]["posts"] else None,
    }

    # Send to Slack / Telegram
    requests.post("https://hooks.slack.com/services/...", json={
        "text": (
            f"📊 Daily Skool digest — {datetime.now():%b %d}\n"
            f"• {summary['total_members']} members ({summary['new_posts_24h']} new posts in 24h)\n"
            f"• {summary['pending_applicants']} pending applicants\n"
            f"• Top post: {summary['top_post']['title'] if summary['top_post'] else '—'}"
        )
    })

daily_digest()
```

## Deployment options

### GitHub Actions (free for personal use)

`.github/workflows/skool-bot.yml`:

```yaml
name: Skool daily bot
on:
  schedule:
    - cron: "0 13 * * *"   # 9am Chile (13:00 UTC)
  workflow_dispatch:

jobs:
  run:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: {python-version: "3.11"}
      - run: pip install requests
      - run: python bot.py
        env:
          APIFY_TOKEN: ${{ secrets.APIFY_TOKEN }}
          SKOOL_COOKIES: ${{ secrets.SKOOL_COOKIES }}
          SKOOL_GROUP_SLUG: ${{ secrets.SKOOL_GROUP_SLUG }}
```

Pros: free, version-controlled, easy. Cons: only schedule-triggered (no webhooks).

### Cron on a VPS

```bash
# crontab -e
0 9 * * * cd /opt/skool-bot && /usr/bin/python3 bot.py >> bot.log 2>&1
```

Pros: full control, easy to debug. Cons: you maintain a VPS.

### Cloud Run / Fly.io / Railway

Containerize the bot, deploy as a scheduled job or HTTP service. Best for webhook-triggered bots.

```dockerfile
FROM python:3.11-slim
RUN pip install requests
COPY bot.py /app/bot.py
WORKDIR /app
CMD ["python", "bot.py"]
```

## Cookie rotation in long-running bots

```python
def actor_with_rotation(action, params):
    result = actor(action, params)
    if not result.get("success") and result.get("errorCode") == "WAF_EXPIRED":
        # Rotate cookies
        login = actor("auth:login", {
            "email": os.environ["SKOOL_EMAIL"],
            "password": os.environ["SKOOL_PASSWORD"],
            "groupSlug": GROUP,
        })
        if login.get("success"):
            global COOKIES
            COOKIES = login["cookies"]
            # Persist back to your secret store / env / vault
            save_cookies_somewhere(COOKIES)
            return actor(action, params)
    return result
```

For GitHub Actions: write new cookies back to GitHub secret using `gh secret set`. For Cloud Run / Fly.io: write to a small KV store (Redis, Cloudflare KV, or even Apify's own key-value store).

## Bot ethics

The actor authenticates as the community owner — your credentials, your community. Don't use this against communities you don't own or admin. Don't spam Skool's rate limit (~25 writes/min). Don't auto-publish content that you wouldn't post yourself.

For comment replies and DMs especially: **maintain a human approval step** until you trust the tone. The first 100 auto-replies should all be human-approved. After that, lower-stakes operations can run fully autonomous.

## Production gotchas

- **Cookie expiry will silently break your bot.** Add `WAF_EXPIRED` handling from day one, not "later".
- **Idempotency:** Track what you've already done. `posts:create` is non-idempotent — if your bot retries on transient error, you might post twice. Store post IDs you've created, check before re-posting.
- **Rate limit ~25 writes/min** — if your bot generates a burst, batch or sleep.
- **`memberId` ≠ `id`** — for any member action, use `memberId` from `members:pending` not the global `user_id`.

## Related

- [Skool API documentation](../learn/skool-api.md)
- [Skool automation hub](skool-automation.md)
- [Skool integrations](../integrations/)
- [Recipes](../recipes/)

---

## Build your Skool bot today

[**→ Open the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=automation&utm_campaign=skool-bot&fpr=cristian)

One HTTP POST per Skool action. Deploy anywhere that runs scripts. Pay-per-event (~$1.50/mo for typical bot usage).

*No Skool community yet? [Launch one in 10 minutes](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{"@context":"https://schema.org","@type":"TechArticle","headline":"Skool Bot","datePublished":"2026-05-19","author":{"@type":"Person","name":"Cristian Tala"}}
</script>
