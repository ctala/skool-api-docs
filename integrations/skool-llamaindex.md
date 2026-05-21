---
title: "Skool + LlamaIndex — Give Your Agent a Skool FunctionTool (2026)"
description: "Connect Skool to LlamaIndex with a FunctionTool. Wrap the Apify-hosted Skool actor, hand it to a FunctionAgent, and let your agent approve members, post, and publish courses."
slug: /integrations/skool-llamaindex
type: integration
primary_keyword: "skool llamaindex"
search_volume_monthly: 0
funnel: A
playbook: integrations
last_updated: 2026-05-21
canonical: https://ctala.github.io/skool-api-docs/integrations/skool-llamaindex/
render_with_liquid: false
---


> **Quick reference (TL;DR for agents)**
> - **What this enables:** any LlamaIndex agent can read AND write to Skool — approve members, post, reply, publish courses — as a `FunctionTool`, with no official Skool API.
> - **Method:** wrap the [Apify-hosted Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-llamaindex) with `FunctionTool.from_defaults(...)` and pass it to a `FunctionAgent(tools=[...])`.
> - **Auth flow:** `auth:login` once → `cookies` string in env → reuse for ~3.5 days.
> - **Latency:** ~2s per action (cookies cached) / ~10s on `auth:login` cold start.
> - **Cost:** Apify pay-per-event (~$0.005–$0.01 per Skool action). LlamaIndex on your existing LLM provider.

## Why LlamaIndex + Skool?

Skool has **no official API**. LlamaIndex is great at retrieval and at calling tools, but there's no built-in connector to act on a Skool community — your agent can reason about Skool data only if something fetches and writes it for real.

The [Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-llamaindex) turns every Skool admin action into one HTTP POST with a structured `{ success, data }` / `{ success, errorCode, hint }` response. That's exactly the shape `FunctionTool` expects: define one Python function, hand it to `FunctionTool.from_defaults`, and your `FunctionAgent` can read and write Skool. One tool, the whole surface — no SDK, no Playwright in your runtime.

Why LlamaIndex specifically fits well here:

1. **`FunctionTool` is the lightest tool primitive going.** A single typed function with a docstring becomes a callable tool — no schema boilerplate.
2. **Pairs with retrieval.** Index your community's posts or course content as a query engine *and* give the agent the Skool write tool — read context, then act.
3. **`FunctionAgent` runs the loop for you.** Plan → call tool → read result → decide, with the actor's LLM-readable `hint` driving recovery.

## The tool — `FunctionTool`

Wrap the actor in one function and register it. Set `APIFY_TOKEN`, `SKOOL_COOKIES`, and `SKOOL_GROUP_SLUG` in your environment first.

```python
import os
import requests
from llama_index.core.tools import FunctionTool

def skool_action(action: str, params: dict | None = None) -> dict:
    """Perform a read or write action on a Skool community via the Apify-hosted
    Skool All-in-One API actor.

    action: e.g. 'posts:create', 'members:pending', 'members:approve'.
            See https://ctala.github.io/skool-api-docs/docs/actions/
    params: action-specific dict. members approve/reject use memberId (NOT id).
            Comment reply: parentId = comment id, rootId = post id.

    Returns {success: true, data: ...} or {success: false, errorCode, hint}.
    On failure, read the 'hint' field — it tells you what to do next.
    """
    token = os.environ["APIFY_TOKEN"]
    url = (
        "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api"
        "/run-sync-get-dataset-items"
        f"?token={token}&build=latest&timeout=90"
    )
    resp = requests.post(
        url,
        json={
            "action": action,
            "cookies": os.environ["SKOOL_COOKIES"],
            "groupSlug": os.environ["SKOOL_GROUP_SLUG"],
            "params": params or {},
        },
        timeout=120,
    )
    resp.raise_for_status()
    data = resp.json()
    # the actor returns a list; the first item is the result
    return data[0] if isinstance(data, list) and data else data

skool_tool = FunctionTool.from_defaults(
    fn=skool_action,
    name="skool_action",
    description=(
        "Perform a Skool action via the Apify-hosted actor. Returns structured "
        "{success, data} or {success: false, errorCode, hint}. members approve/reject "
        "use memberId (NOT id). Comment reply: parentId = comment id, rootId = post id."
    ),
)
```

## Example — a community-manager agent

A single `FunctionAgent` that clears the waitlist and posts a welcome.

```python
import asyncio
from llama_index.llms.anthropic import Anthropic
from llama_index.core.agent.workflow import FunctionAgent

llm = Anthropic(model="claude-opus-4-7", api_key=os.environ["ANTHROPIC_API_KEY"])

agent = FunctionAgent(
    tools=[skool_tool],
    llm=llm,
    system_prompt=(
        "You operate a Skool community via the skool_action tool. "
        "Approve only applicants with a reachable LinkedIn and a specific survey answer. "
        "Use memberId (from members:pending), never id. Posts are plain text."
    ),
)

async def main():
    response = await agent.run(
        "List my pending Skool members. Approve the ones with a real LinkedIn using "
        "members:batchApprove. Then post a 2-sentence welcome naming them. "
        "Give me a one-line summary of who you approved and who you left for review."
    )
    print(response)

asyncio.run(main())
```

The agent calls `members:pending`, screens the queue, batch-approves the clear yeses, then `posts:create`s the welcome — typically under $0.05 for a full waitlist clear. The task pattern is detailed in [Review & batch-approve your waitlist](../recipes/review-and-batch-approve-waitlist.md).

Prefer a reasoning-trace agent? `ReActAgent` takes the same tool list:

```python
from llama_index.core.agent.workflow import ReActAgent

agent = ReActAgent(tools=[skool_tool], llm=llm)
```

## Auto-rotate cookies on `WAF_EXPIRED`

Skool cookies age out about every 3.5 days. Wrap the call so the agent never sees the error:

```python
def skool_action_safe(action: str, params: dict | None = None) -> dict:
    result = skool_action(action, params)
    if not result.get("success") and result.get("errorCode") == "WAF_EXPIRED":
        login = skool_action("auth:login", {
            "email": os.environ["SKOOL_EMAIL"],
            "password": os.environ["SKOOL_PASSWORD"],
            "groupSlug": os.environ["SKOOL_GROUP_SLUG"],
        })
        if login.get("success"):
            os.environ["SKOOL_COOKIES"] = login["cookies"]
            return skool_action(action, params)
    return result

skool_tool = FunctionTool.from_defaults(fn=skool_action_safe, name="skool_action")
```

Register `skool_action_safe` instead of `skool_action` and re-logins happen transparently.

## Production gotchas

- **`x402-payment-required` on every call:** Not a billing issue — it's a stale `UNDER_MAINTENANCE` flag from Apify's heuristic. Open the [actor page](https://apify.com/cristiantala/skool-all-in-one-api) in Apify Console once to reset. Details in [error handling](../docs/error-handling.md).
- **Cookies expiring silently:** When a call returns `errorCode: "WAF_EXPIRED"`, re-run `auth:login` and refresh `SKOOL_COOKIES`. Use the auto-rotate wrapper above for unattended agents.
- **`parentId` for comment replies:** top-level comment → `rootId == parentId == postId`. Reply to a comment → `rootId == postId`, `parentId == commentId`. Mixing these is the most common silent bug.
- **`memberId` vs `id`:** for approve/reject, pass `memberId` from `members:pending`, not the `id`. The wrong one gives a silent 404. Keep this in the tool description so the agent picks the right field.
- **Rate limit ~25 writes/min:** Skool's hard limit. The actor queues internally — don't add your own retry loop. For bulk approvals use `members:batchApprove`.
- **Return the dict, don't stringify it:** `FunctionTool` passes the return value back to the LLM. Return the parsed JSON dict so the agent can read `success` and `hint` directly — don't `json.dumps` it. For async agents, register an async `fn` and LlamaIndex awaits it on `agent.run`.

## Hand this to your agent

Already have a tool-calling loop? Drop in the function body and give the LLM this primer — full first available at [Skool for AI agents](../for/ai-agents.md):

```python
def skool_action(action: str, params: dict | None = None) -> dict:
    import os, requests
    r = requests.post(
        "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api"
        f"/run-sync-get-dataset-items?token={os.environ['APIFY_TOKEN']}&build=latest&timeout=90",
        json={"action": action, "cookies": os.environ["SKOOL_COOKIES"],
              "groupSlug": os.environ["SKOOL_GROUP_SLUG"], "params": params or {}},
        timeout=120,
    )
    d = r.json()
    return d[0] if isinstance(d, list) and d else d
```

```
Skool has no official API; the Apify actor cristiantala/skool-all-in-one-api is it.
Every action is ONE POST. Actions: posts:* members:* events:* classroom:* files:* groups:* auth:login.
Rules: members approve/reject use params.memberId (NOT id). Comment reply: parentId=comment id,
rootId=post id. Posts are plain text. ~25 writes/min (actor queues — no retry loop). On
errorCode "WAF_EXPIRED" re-run auth:login. Read `hint` to recover. Full params:
https://ctala.github.io/skool-api-docs/docs/actions/
```

## Other Python frameworks

Using a different framework? The wrapper is the same POST behind a different tool interface:

- [Skool + LangChain](skool-langchain.md) — `StructuredTool` wrapper + LangGraph
- [Skool + CrewAI](skool-crewai.md) — `BaseTool` / `@tool` for role-based crews
- [Skool + Python](skool-python.md) — the raw `requests` client these all wrap

## See also

- [Skool for AI agents](../for/ai-agents.md) — full pattern library + function-calling specs
- [Actions reference](../docs/actions.md) — complete list of actions and params
- [Error handling](../docs/error-handling.md) — x402, WAF_EXPIRED, rate limits
- [Recipe: Review & batch-approve your waitlist](../recipes/review-and-batch-approve-waitlist.md)
- [All integrations →](index.md)

---

## Plug Skool into your LlamaIndex agent today

[**→ Use the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-llamaindex)

- Pay-per-event (~$0.005–$0.01 per Skool action, ~$1.50/mo typical)
- Read AND write — full API surface (posts, comments, members, classroom, files, Auto DM)
- One `FunctionTool` wraps the whole surface — works with any LlamaIndex LLM

*No Skool community yet? [Launch one in 10 minutes](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "TechArticle",
  "headline": "Skool + LlamaIndex — Give Your Agent a Skool FunctionTool",
  "description": "Connect Skool to LlamaIndex with a FunctionTool. Wrap the Apify-hosted Skool actor, hand it to a FunctionAgent, and let your agent approve members, post, and publish courses.",
  "datePublished": "2026-05-21",
  "dateModified": "2026-05-21",
  "author": {
    "@type": "Person",
    "name": "Cristian Tala",
    "url": "https://cristiantala.com"
  },
  "publisher": {
    "@type": "Person",
    "name": "Cristian Tala",
    "url": "https://cristiantala.com"
  },
  "mainEntityOfPage": "https://ctala.github.io/skool-api-docs/integrations/skool-llamaindex/"
}
</script>
