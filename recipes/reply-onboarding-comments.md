---
title: "Auto-Reply to Skool Onboarding Comments — Pinned 'Start Here' Threads"
description: "Detect unanswered comments in pinned onboarding threads, draft contextual replies, approve in Telegram, publish. Production recipe from a 484-member community."
slug: /recipes/reply-onboarding-comments
type: recipe
primary_keyword: "reply skool comments automatically"
search_volume_monthly: null
funnel: A
playbook: recipes
last_updated: 2026-05-19
canonical: https://github.com/ctala/skool-api-docs/blob/main/recipes/reply-onboarding-comments.md
---

# Auto-Reply to Skool Onboarding Comments

> **Quick reference (TL;DR for agents)**
> - **Goal:** Detect comments in pinned onboarding threads where the community owner hasn't replied, draft contextual responses based on the post type, get human approval, publish.
> - **Stack:** Python script (or n8n equivalent) + Apify actor + your choice of LLM
> - **Actor actions used:** `auth:login` → direct `/posts/{id}/comments` fetch → `posts:createComment`
> - **Setup time:** ~20 min
> - **Ongoing cost:** ~$0.50/mo on Apify + ~$0.30/mo in LLM (typical 30 onboarding replies/month)

## What this recipe does

Most communities have pinned "Start Here" and "Introduce Yourself" threads. New members drop comments in those threads, the owner never gets back to all of them, and 1-week retention silently drops. This recipe finds the unanswered comments, drafts a reply that's actually specific to what the member wrote (not "Welcome! 🎉"), surfaces them for approval, and publishes once approved.

In production on [a 484-member community](https://www.skool.com/cagala-aprende-repite), this pattern keeps 1-week retention above 60% versus ~30% baseline before automation.

## Prerequisites

- Apify token ([get one](https://console.apify.com/account/integrations))
- Skool admin credentials for the community
- An LLM API key (Claude, OpenAI, or any model with structured output)
- A way to receive approvals (Telegram bot, Slack DM, or a CLI prompt)

## The bug everyone hits first

Replying to a comment inside a thread requires a specific payload shape that the Skool web app uses internally — and it's the #1 silent failure for agents writing their first comment recipe.

For a **top-level comment** on a post:

```json
{
  "rootId": "{postId}",
  "parentId": "{postId}",     // ← same as rootId
  "content": "..."
}
```

For a **nested reply to an existing comment** (the case for onboarding):

```json
{
  "rootId": "{postId}",       // ← still the post id
  "parentId": "{commentId}",  // ← the COMMENT you're replying to, not the post
  "content": "..."
}
```

If you set `parentId == postId` when you meant to reply to a member's comment, your reply will publish as a new top-level comment instead of nested. The Skool UI shows top-level replies in chronological order with no thread context — the member you intended to greet has no idea you replied to them. We've seen agents lose 1-2 weeks getting this right; document it once and never debug it again.

## Step 1 — Bootstrap Skool cookies

```bash
curl -X POST "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=YOUR_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "action": "auth:login",
    "email": "admin@yourcommunity.com",
    "password": "your-skool-password",
    "groupSlug": "your-community"
  }'
```

Save the `cookies` string. Valid ~3.5 days.

## Step 2 — List the pinned threads you want to monitor

Most communities have 1-3 pinned onboarding threads. Use [`posts:list`](../docs/posts.md) with `pinned: true`, or just hardcode the `postId` of each (they don't change).

For [Cágala, Aprende, Repite](https://www.skool.com/cagala-aprende-repite):

```python
PINNED_THREADS = {
    "4fccea23339547c48360c57cab857e54": "Start Here",
    "3bc910b12bd0443f886e13c5ac28a08a": "Introduce Yourself",
}
```

## Step 3 — Fetch the full comment tree (newest + tail)

This is the second gotcha: the actor's `posts:getComments` returns only the most recent ~25 top-level comments. For full coverage of older threads (which onboarding pinned posts always are), you must call the Skool internal endpoint with both `pinned=true` (gets newest) AND `tail=true` (gets oldest) and merge.

```python
import urllib.request, json

UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
GROUP_ID = "055ca036e2004bc1acbc51af14dbdf4d"  # from groups:get

def fetch_comments_full(post_id: str, cookies: str) -> list:
    all_children = []
    seen = set()
    for params in [
        {"group-id": GROUP_ID, "limit": "25", "pinned": "true"},
        {"group-id": GROUP_ID, "tail": "true"},
    ]:
        qs = "&".join(f"{k}={v}" for k, v in params.items())
        req = urllib.request.Request(
            f"https://api.skool.com/posts/{post_id}/comments?{qs}",
            headers={"Cookie": cookies, "User-Agent": UA, "Accept": "application/json"},
        )
        d = json.loads(urllib.request.urlopen(req, timeout=20).read())
        for c in d.get("post_tree", {}).get("children", []):
            pid = c.get("post", {}).get("id")
            if pid and pid not in seen:
                seen.add(pid)
                all_children.append(c)
    return all_children
```

## Step 4 — Filter to "no reply from me"

For each top-level comment, check its `children` array. If your user_id appears in any child's `user_id` field, you've replied. Skip.

```python
OWNER_USER_IDS = {"your_skool_user_id_here"}  # JWT-confirmed

def needs_reply(comment) -> bool:
    if comment["post"].get("user_id") in OWNER_USER_IDS:
        return False  # this is YOUR top-level comment
    for child in comment.get("children", []) or []:
        if child.get("post", {}).get("user_id") in OWNER_USER_IDS:
            return False  # you already replied
    return True
```

## Step 5 — Draft replies that are actually specific

Here's where most automations fail: they generate "Welcome to the community! 🚀" for every member and the member can tell. The bar for value is that the reply references something the member actually wrote.

A reply framework that works (used in production on CAR):

| Context | Apertura | Body | Cierre |
|---|---|---|---|
| **Start Here** thread (≤5 word comments) | `Bienvenido, {name}.` | If the comment is rich (≥50 chars), 1 micro-tip extracted from the comment. If thin, invite them to the "Introduce Yourself" thread. | Optional: invite to publish first real question in feed. |
| **Introduce Yourself** thread | `Bienvenida, {name}.` | Acknowledge ONE specific thing from their intro (industry, stage, current challenge) + 1 actionable insight specific to that context. | Invite them to share a concrete dilemma in the feed for community help. |

Prompt template:

```
You are responding to a new member's comment in a "{thread_type}" pinned thread in {community_name}.

Tone: founder-to-founder. Direct. Specific. Spanish (es-LATAM, neutral — no voseo).

The member wrote:
"""
{comment_content}
"""

Member's first name: {first_name}

Requirements:
- Open with "Bienvenido/a, {first_name}."
- Reference ONE specific thing from their comment (not generic).
- Add ONE actionable insight or question.
- Maximum {length} words.
- If the comment is ≤5 words and gives no anchor, return literally "SKIP".

Reply text only, no preamble.
```

Reject and regenerate any reply that:
- Starts with "Welcome to the community!"
- Doesn't name the member
- Uses 2+ emojis
- Is the same length and structure as the previous 3 you generated

## Step 6 — Human approval before publishing

Send each draft to Telegram (or Slack) with the original comment context and approve/reject buttons. Reply within 24h or skip.

```python
def request_approval(member_name: str, original: str, draft: str) -> bool:
    """Returns True if approved, False to skip."""
    # Send to Telegram bot, wait for /yes_{shortId} or /no_{shortId}
    # See https://github.com/ctala/skool-api-docs/blob/main/recipes/reply-unanswered-posts.md
    ...
```

For the first 30-50 replies, **require approval every time** so you can catch tone drift. After that, lower-stakes communities can publish directly.

## Step 7 — Publish the reply (with the correct payload!)

```python
def reply_to_comment(thread_id: str, comment_id: str, content: str, cookies: str, apify_token: str) -> dict:
    payload = {
        "action": "posts:createComment",
        "cookies": cookies,
        "groupSlug": "your-community",
        "params": {
            "rootId":   thread_id,    # the pinned post
            "parentId": comment_id,   # ← the member's comment, NOT the post id
            "content":  content,
        }
    }
    req = urllib.request.Request(
        f"https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token={apify_token}&build=latest&timeout=60",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    return json.loads(urllib.request.urlopen(req, timeout=70).read())[0]
```

Verify `success: true` and a `reply_id` in the response.

## Step 8 — Log and iterate

Save each reply: original comment, draft, edits the human made, final published version, member outcome (did they post in feed after?). After 100 replies, run a delta analysis between draft and final — the patterns the human keeps editing are your prompt improvements.

## Production gotchas

- **`parentId == postId` for nested replies = silent failure.** Reply publishes top-level instead of nested. Member gets no notification. See Step 7 — `rootId` is the pinned post, `parentId` is the member's comment ID.
- **`children` array doesn't include deep-nested replies.** Skool nests only 2 levels (post → comment → reply). If you see a 3rd level in the UI it's actually a reply targeted at the same parent comment but rendered visually nested. The actor returns the flat 2-level structure.
- **Cookies expire (~3.5 days).** Branch on `errorCode: "WAF_EXPIRED"`, call `auth:login` again, retry. Don't ignore this — once cookies expire, every subsequent call fails until you refresh.
- **Validate your own user_id.** New developers sometimes hardcode the wrong user_id (e.g. a co-founder's) and the script never marks any comment as "already replied". Confirm by decoding your JWT or fetching `/auth/me` once.
- **Skip is a feature, not a bug.** Empty 1-word comments ("thanks!", "exciting!") don't need a reply that pretends to engage. Generating "Welcome! Excited to have you here 🚀" for these is worse than silence — it tells the rest of the community you don't care.

## Full Python script

<details>
<summary>Click to expand</summary>

```python
#!/usr/bin/env python3
"""Reply to onboarding comments in pinned Skool threads — with human approval."""
import json, os, urllib.request
from pathlib import Path

APIFY_TOKEN = os.environ["APIFY_TOKEN"]
GROUP_SLUG = "your-community"
GROUP_ID = "..."
COOKIES = Path("/tmp/skool_cookies.txt").read_text().strip()
OWNER_USER_IDS = {"..."}
PINNED_THREADS = {
    "...": "Start Here",
    "...": "Introduce Yourself",
}
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

def actor(payload, timeout=60):
    req = urllib.request.Request(
        f"https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token={APIFY_TOKEN}&build=latest&timeout={timeout}",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    return json.loads(urllib.request.urlopen(req, timeout=timeout + 10).read())

def fetch_comments(post_id):
    """Direct Skool API: combine newest + tail for full coverage."""
    all_children, seen = [], set()
    for params in [
        {"group-id": GROUP_ID, "limit": "25", "pinned": "true"},
        {"group-id": GROUP_ID, "tail": "true"},
    ]:
        qs = "&".join(f"{k}={v}" for k, v in params.items())
        req = urllib.request.Request(
            f"https://api.skool.com/posts/{post_id}/comments?{qs}",
            headers={"Cookie": COOKIES, "User-Agent": UA, "Accept": "application/json"},
        )
        try:
            d = json.loads(urllib.request.urlopen(req, timeout=20).read())
            for c in d.get("post_tree", {}).get("children", []):
                pid = c.get("post", {}).get("id")
                if pid and pid not in seen:
                    seen.add(pid)
                    all_children.append(c)
        except Exception as e:
            print(f"  fetch err {params}: {e}")
    return all_children

def needs_reply(comment):
    if comment["post"].get("user_id") in OWNER_USER_IDS:
        return False
    for child in comment.get("children", []) or []:
        if child.get("post", {}).get("user_id") in OWNER_USER_IDS:
            return False
    return True

def draft_reply(comment, thread_label):
    """Call your LLM here. Return string or 'SKIP'."""
    # ... (LLM call with prompt from Step 5)
    return "..."

def publish_reply(thread_id, comment_id, content):
    return actor({
        "action": "posts:createComment",
        "cookies": COOKIES,
        "groupSlug": GROUP_SLUG,
        "params": {"rootId": thread_id, "parentId": comment_id, "content": content},
    })

for thread_id, label in PINNED_THREADS.items():
    print(f"\n=== {label} ===")
    for c in fetch_comments(thread_id):
        if not needs_reply(c):
            continue
        author = c["post"].get("user", {})
        name = author.get("first_name", "")
        content = (c["post"].get("metadata") or {}).get("content", "")
        print(f"  PENDING: {name}: {content[:60]}")
        draft = draft_reply(c, label)
        if draft.strip() == "SKIP":
            print(f"    → SKIP (no anchor)")
            continue
        print(f"    draft: {draft[:80]}")
        # Show in Telegram, wait for approval, then:
        # publish_reply(thread_id, c["post"]["id"], draft)
```

</details>

## See also

- [Reply to unanswered posts](reply-unanswered-posts.md) — companion recipe for top-level post replies
- [Auto-approve members with n8n](auto-approve-members-n8n.md) — front-of-funnel automation
- [Auto DM new members](auto-dm-new-members.md) — first impression after approval
- [Posts & Comments reference](../docs/posts.md) — the data model

---

## Use this in production today

The Skool internal API, the cookies+WAF+buildId rotation, and the structured-error layer are all handled by the actor — your script just makes JSON POSTs and gets structured responses back.

[**→ Open the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=reply-onboarding-comments)

- Pay-per-event (~$0.005 per fetch, ~$0.01 per reply)
- One HTTP POST per action — works from Python, n8n, Make.com, anywhere
- Battle-tested in production on a 484-member community

*New to Skool? [Launch your community here](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "HowTo",
  "name": "Auto-Reply to Skool Onboarding Comments",
  "description": "Detect unanswered comments in pinned onboarding threads, draft contextual replies, approve in Telegram, publish via the Apify Skool API actor.",
  "totalTime": "PT20M",
  "tool": [
    {"@type": "HowToTool", "name": "Apify"},
    {"@type": "HowToTool", "name": "Python (or n8n)"},
    {"@type": "HowToTool", "name": "Claude or OpenAI"}
  ],
  "step": [
    {"@type": "HowToStep", "name": "Bootstrap cookies", "text": "Call auth:login once, store cookies (~3.5 day TTL)"},
    {"@type": "HowToStep", "name": "List pinned threads", "text": "Hardcode or fetch via posts:list with pinned=true"},
    {"@type": "HowToStep", "name": "Fetch full comment tree", "text": "Combine newest + tail passes for older threads"},
    {"@type": "HowToStep", "name": "Filter unanswered", "text": "Skip if your user_id appears in any child"},
    {"@type": "HowToStep", "name": "Draft specific replies", "text": "LLM with comment-aware prompt, reject generic outputs"},
    {"@type": "HowToStep", "name": "Human approval", "text": "Telegram or Slack with approve/reject buttons"},
    {"@type": "HowToStep", "name": "Publish with correct payload", "text": "rootId=postId, parentId=commentId (NOT postId)"},
    {"@type": "HowToStep", "name": "Log and iterate", "text": "Track edits humans make to improve prompt"}
  ]
}
</script>
