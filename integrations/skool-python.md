---
title: "Skool Python Client — Use the Skool API from Python (2026)"
description: "Use the Skool API from Python. One requests call per action — no SDK to install. Examples for posting, member management, course publishing, and async workflows."
slug: /integrations/skool-python
type: integration
primary_keyword: "skool python"
search_volume_monthly: 10
funnel: A
playbook: integrations
last_updated: 2026-05-19
canonical: https://ctala.github.io/skool-api-docs/integrations/skool-python/
---


> **Quick reference (TL;DR for agents)**
> - **No Python SDK exists** for Skool — there's no official Skool Python package.
> - **The workaround:** call the [Apify-hosted Skool API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-python&fpr=cristian) with `requests` or `httpx`. One POST per action.
> - **Sync, async, and Apify SDK** patterns all supported.

## Why no Python SDK?

Skool has no official API → no official SDK in any language. The Apify actor wraps Skool's internal API behind a single HTTP endpoint. Calling it from Python is one `requests.post()`. Wrapping that in a small Python class gives you SDK-like ergonomics in ~30 lines.

## Minimal client

```python
import os
import requests

class SkoolClient:
    """Minimal Skool API client via the Apify-hosted actor."""

    BASE = "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items"

    def __init__(self, apify_token: str, cookies: str, group_slug: str):
        self.apify_token = apify_token
        self.cookies = cookies
        self.group_slug = group_slug

    def call(self, action: str, params: dict = None) -> dict:
        resp = requests.post(
            f"{self.BASE}?token={self.apify_token}&build=latest&timeout=90",
            json={
                "action": action,
                "cookies": self.cookies,
                "groupSlug": self.group_slug,
                "params": params or {},
            },
            timeout=120,
        )
        resp.raise_for_status()
        data = resp.json()
        # actor returns a list; first item is the result
        return data[0] if isinstance(data, list) and data else data

    # Convenience wrappers
    def list_pending(self):
        return self.call("members:pending")

    def approve(self, member_id: str):
        return self.call("members:approve", {"memberId": member_id})

    def post(self, title: str, content: str, label_id: str = None):
        params = {"title": title, "content": content}
        if label_id:
            params["labelId"] = label_id
        return self.call("posts:create", params)

    def reply_to_comment(self, post_id: str, comment_id: str, content: str):
        return self.call("posts:createComment", {
            "rootId": post_id,
            "parentId": comment_id,   # NOT postId — that publishes top-level instead of nested
            "content": content,
        })

# Usage
client = SkoolClient(
    apify_token=os.environ["APIFY_TOKEN"],
    cookies=os.environ["SKOOL_COOKIES"],
    group_slug="your-community",
)

# Approve pending members
pending = client.list_pending()
for m in pending.get("data", {}).get("members", []):
    client.approve(m["memberId"])
```

## Bootstrap cookies — one-time

```python
def login_and_save_cookies(email: str, password: str, group_slug: str, apify_token: str) -> str:
    resp = requests.post(
        f"https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token={apify_token}&timeout=90",
        json={
            "action": "auth:login",
            "email": email,
            "password": password,
            "groupSlug": group_slug,
        },
        timeout=120,
    )
    data = resp.json()[0]
    if not data.get("success"):
        raise RuntimeError(f"auth:login failed: {data}")
    return data["cookies"]   # valid ~3.5 days
```

Save the returned cookies to disk, env var, or a vault. Reuse for ~3.5 days. Re-run when `errorCode == "WAF_EXPIRED"`.

## Async with httpx

```python
import httpx, asyncio

class AsyncSkoolClient:
    def __init__(self, apify_token, cookies, group_slug):
        self.token = apify_token
        self.cookies = cookies
        self.group_slug = group_slug
        self._client = httpx.AsyncClient(timeout=120.0)

    async def call(self, action, params=None):
        resp = await self._client.post(
            f"https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token={self.token}&build=latest&timeout=90",
            json={"action": action, "cookies": self.cookies, "groupSlug": self.group_slug, "params": params or {}}
        )
        data = resp.json()
        return data[0] if isinstance(data, list) and data else data

    async def close(self):
        await self._client.aclose()

# Run many actions in parallel (READS only — writes hit Skool's rate limit)
async def main():
    client = AsyncSkoolClient(os.environ["APIFY_TOKEN"], os.environ["SKOOL_COOKIES"], "your-community")
    courses, members, posts = await asyncio.gather(
        client.call("classroom:listCourses"),
        client.call("members:list"),
        client.call("posts:list", {"page": 1, "limit": 50}),
    )
    await client.close()

asyncio.run(main())
```

## Auto-rotate cookies

```python
class SkoolClient:
    # ... base class above ...

    def call_with_retry(self, action, params=None):
        result = self.call(action, params)
        if not result.get("success") and result.get("errorCode") == "WAF_EXPIRED":
            # cookies expired — rotate
            self.cookies = login_and_save_cookies(
                os.environ["SKOOL_EMAIL"],
                os.environ["SKOOL_PASSWORD"],
                self.group_slug,
                self.apify_token,
            )
            os.environ["SKOOL_COOKIES"] = self.cookies   # persist via your config layer
            return self.call(action, params)   # retry with fresh cookies
        return result
```

## Using the Apify Python SDK

If you're already using `apify-client`, the SDK is a thin wrapper around the same endpoint:

```python
from apify_client import ApifyClient

client = ApifyClient(token=os.environ["APIFY_TOKEN"])

run = client.actor("cristiantala/skool-all-in-one-api").call(
    run_input={
        "action": "posts:create",
        "cookies": os.environ["SKOOL_COOKIES"],
        "groupSlug": "your-community",
        "params": {"title": "Hello from Python", "content": "First automated post."},
    },
    build="latest",
    timeout_secs=90,
)
# Fetch results from the run's default dataset
items = list(client.dataset(run["defaultDatasetId"]).iterate_items())
print(items[0])
```

The raw `requests` approach is slightly faster (no SDK overhead) and has fewer dependencies. The Apify SDK is convenient if you're running other Apify actors in the same project.

## Production patterns

- **Don't run two `SkoolClient` instances against the same Apify actor key concurrently** — they share Skool's rate limit and the actor's session state.
- **Cache results.** `classroom:listCourses` and `members:list` change slowly. Cache for 5-10 minutes in production.
- **Log structured errors.** When `success: false`, log the full `{errorCode, errorCategory, hint, retryable}` — those fields are explicitly designed for log search.
- **Use `members:batchApprove` for bulk approvals.** It bypasses the per-call rate limit because Skool handles it server-side.

## Related

- [Skool + Claude / Anthropic SDK](skool-claude.md)
- [Skool + LangChain](skool-langchain.md)
- [Skool for AI agents](../for/ai-agents.md)
- [Skool API documentation](../learn/skool-api-documentation.md)

---

## Start using Skool from Python today

[**→ Open the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-python&fpr=cristian)

No SDK to install. Just `requests` (or `httpx`, or `apify-client`). One POST per action. Pay-per-event (~$1.50/mo typical).

*No Skool community yet? [Launch one in 10 minutes](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{"@context":"https://schema.org","@type":"TechArticle","headline":"Skool Python Client","datePublished":"2026-05-19","author":{"@type":"Person","name":"Cristian Tala"}}
</script>
