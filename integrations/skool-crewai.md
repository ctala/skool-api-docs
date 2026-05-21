---
title: "Skool + CrewAI — Give Your Crew a Skool Tool (2026)"
description: "Connect Skool to CrewAI with a custom tool. Wrap the Apify-hosted Skool actor as a BaseTool or @tool, hand it to an Agent, and let your crew approve members, post, and publish courses."
slug: /integrations/skool-crewai
type: integration
primary_keyword: "skool crewai"
search_volume_monthly: 0
funnel: A
playbook: integrations
last_updated: 2026-05-21
canonical: https://ctala.github.io/skool-api-docs/integrations/skool-crewai/
render_with_liquid: false
---


> **Quick reference (TL;DR for agents)**
> - **What this enables:** any CrewAI agent or crew can read AND write to Skool — approve members, post, reply, publish courses — as a custom tool, with no official Skool API.
> - **Method:** wrap the [Apify-hosted Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-crewai) in a CrewAI `BaseTool` (or `@tool`) that POSTs one JSON body, then add it to `Agent(tools=[...])`.
> - **Auth flow:** `auth:login` once → `cookies` string in env → reuse for ~3.5 days.
> - **Latency:** ~2s per action (cookies cached) / ~10s on `auth:login` cold start.
> - **Cost:** Apify pay-per-event (~$0.005–$0.01 per Skool action). CrewAI on your existing LLM provider.

## Why CrewAI + Skool?

Skool has **no official API**. If you build multi-agent crews, there's no off-the-shelf Skool tool to drop into `Agent(tools=[...])` — so a community-manager crew has nothing to actually act on Skool with.

The [Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-crewai) turns every Skool admin action into one HTTP POST with a structured `{ success, data }` / `{ success, errorCode, hint }` response. That maps cleanly onto CrewAI's tool model: one `BaseTool` subclass wraps the actor, the Pydantic `args_schema` describes the call, and `_run` does the POST. One tool, the entire Skool surface — no SDK, no Playwright in your runtime.

Why CrewAI specifically fits well here:

1. **Role-based agents map to community jobs.** A "Moderator" agent, an "Onboarding" agent, and an "Editor" agent can all share the same Skool tool with different goals.
2. **The actor's `hint` field is LLM-readable.** When a call fails (`WAF_EXPIRED`, `MEMBER_NOT_FOUND`), the crew reads the `hint` and self-corrects — no try/except plumbing in your task code.
3. **Sequential and hierarchical crews.** "Fetch pending → screen → approve → post a welcome" is a natural CrewAI task chain over one tool.

## The tool — `BaseTool` subclass

This wraps the whole actor in a single tool. Set `APIFY_TOKEN`, `SKOOL_COOKIES`, and `SKOOL_GROUP_SLUG` in your environment first.

```python
import os
import requests
from typing import Type
from crewai.tools import BaseTool
from pydantic import BaseModel, Field

class SkoolActionInput(BaseModel):
    """Input schema for the Skool tool."""
    action: str = Field(
        ...,
        description="Skool action, e.g. 'posts:create', 'members:pending', 'members:approve'. "
                    "See https://ctala.github.io/skool-api-docs/docs/actions/",
    )
    params: dict = Field(
        default_factory=dict,
        description="Action-specific params. members approve/reject use memberId (NOT id). "
                    "Comment reply: parentId = comment id, rootId = post id.",
    )

class SkoolTool(BaseTool):
    name: str = "skool_action"
    description: str = (
        "Perform a read or write operation on a Skool community via the Apify-hosted "
        "Skool All-in-One API actor. Returns {success: true, data: ...} or "
        "{success: false, errorCode, hint}. On failure, read 'hint' — it says what to do next."
    )
    args_schema: Type[BaseModel] = SkoolActionInput

    def _run(self, action: str, params: dict) -> dict:
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

skool_tool = SkoolTool()
```

Prefer the lightweight decorator? Same call, fewer lines:

```python
import os, requests
from crewai.tools import tool

@tool("skool_action")
def skool_action(action: str, params: dict) -> dict:
    """Perform a Skool action via the Apify-hosted actor. Returns {success, data} or
    {success: false, errorCode, hint}. members approve/reject use memberId (NOT id)."""
    token = os.environ["APIFY_TOKEN"]
    resp = requests.post(
        "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api"
        "/run-sync-get-dataset-items"
        f"?token={token}&build=latest&timeout=90",
        json={
            "action": action,
            "cookies": os.environ["SKOOL_COOKIES"],
            "groupSlug": os.environ["SKOOL_GROUP_SLUG"],
            "params": params or {},
        },
        timeout=120,
    )
    data = resp.json()
    return data[0] if isinstance(data, list) and data else data
```

## Example — a community-manager crew

A two-agent crew: a Moderator screens and approves the waitlist, then an Onboarding agent posts a welcome. Both share the one Skool tool.

```python
from crewai import Agent, Task, Crew, Process

moderator = Agent(
    role="Community Moderator",
    goal="Approve pending Skool members who have a real, reachable LinkedIn; flag the rest.",
    backstory="You guard quality. You approve clear yeses and never guess on borderline cases.",
    tools=[skool_tool],
    verbose=True,
)

onboarder = Agent(
    role="Onboarding Host",
    goal="Welcome newly approved members with a short, warm community post.",
    backstory="You make new members feel they made the right call joining.",
    tools=[skool_tool],
    verbose=True,
)

screen_and_approve = Task(
    description=(
        "Call skool_action with action='members:pending' to fetch the approval queue. "
        "For each applicant with a reachable LinkedIn and a specific survey answer, collect "
        "their memberId. Then approve them with action='members:batchApprove' and "
        "params={'memberIds': [...]}. Return the list of approved names and the borderline ones."
    ),
    expected_output="A list of approved members and a list of borderline applicants to review.",
    agent=moderator,
)

welcome_post = Task(
    description=(
        "Write a 2-3 sentence welcome post naming the new members from the previous task, then "
        "publish it with action='posts:create' and params={'title': ..., 'content': ...}. "
        "Posts are plain text — no markdown or HTML."
    ),
    expected_output="Confirmation that the welcome post was created, with its post id.",
    agent=onboarder,
)

crew = Crew(
    agents=[moderator, onboarder],
    tasks=[screen_and_approve, welcome_post],
    process=Process.sequential,
    verbose=True,
)

result = crew.kickoff()
print(result)
```

That run costs roughly a cent per approved member plus one post — typically under $0.05 for a full waitlist clear. The full task pattern is in [Review & batch-approve your waitlist](../recipes/review-and-batch-approve-waitlist.md).

## Auto-rotate cookies on `WAF_EXPIRED`

Skool cookies age out about every 3.5 days. Wrap the POST so the crew never sees the error:

```python
def call_skool(action: str, params: dict) -> dict:
    result = skool_tool._run(action, params)
    if not result.get("success") and result.get("errorCode") == "WAF_EXPIRED":
        login = skool_tool._run("auth:login", {
            "email": os.environ["SKOOL_EMAIL"],
            "password": os.environ["SKOOL_PASSWORD"],
            "groupSlug": os.environ["SKOOL_GROUP_SLUG"],
        })
        if login.get("success"):
            os.environ["SKOOL_COOKIES"] = login["cookies"]
            return skool_tool._run(action, params)
    return result
```

Call `call_skool` from inside a thin tool instead of `_run` directly, and re-logins happen transparently.

## Production gotchas

- **`x402-payment-required` on every call:** Not a billing issue — it's a stale `UNDER_MAINTENANCE` flag from Apify's heuristic. Open the [actor page](https://apify.com/cristiantala/skool-all-in-one-api) in Apify Console once to reset. Details in [error handling](../docs/error-handling.md).
- **Cookies expiring silently:** When a call returns `errorCode: "WAF_EXPIRED"`, re-run `auth:login` and refresh `SKOOL_COOKIES`. Use the auto-rotate wrapper above for unattended crews.
- **`parentId` for comment replies:** top-level comment → `rootId == parentId == postId`. Reply to a comment → `rootId == postId`, `parentId == commentId`. Mixing these is the most common silent bug.
- **`memberId` vs `id`:** for approve/reject, pass `memberId` from `members:pending`, not the `id`. The wrong one gives a silent 404. Put this in the tool description so the agent picks the right field.
- **Rate limit ~25 writes/min:** Skool's hard limit. The actor queues internally — don't make the crew add a retry loop. For bulk approvals use `members:batchApprove`, which Skool handles server-side.
- **Tool returns a dict, not a string:** CrewAI passes the dict back to the LLM as-is. Keep `_run` returning the parsed JSON so the agent can read `success` and `hint` — don't `json.dumps` it into a string.

## Hand this to your agent

Already have a tool-calling agent in your crew? Drop the actor's `_run` body into one tool method and give the LLM this primer — full first available at [Skool for AI agents](../for/ai-agents.md):

```python
def _run(self, action: str, params: dict) -> dict:
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
- [Skool + LlamaIndex](skool-llamaindex.md) — `FunctionTool` + `FunctionAgent`
- [Skool + Python](skool-python.md) — the raw `requests` client these all wrap

## See also

- [Skool for AI agents](../for/ai-agents.md) — full pattern library + function-calling specs
- [Actions reference](../docs/actions.md) — complete list of actions and params
- [Error handling](../docs/error-handling.md) — x402, WAF_EXPIRED, rate limits
- [Recipe: Review & batch-approve your waitlist](../recipes/review-and-batch-approve-waitlist.md)
- [All integrations →](index.md)

---

## Plug Skool into your CrewAI crew today

[**→ Use the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-crewai)

- Pay-per-event (~$0.005–$0.01 per Skool action, ~$1.50/mo typical)
- Read AND write — full API surface (posts, comments, members, classroom, files, Auto DM)
- One `BaseTool` wraps the whole surface — works with any CrewAI LLM provider

*No Skool community yet? [Launch one in 10 minutes](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "TechArticle",
  "headline": "Skool + CrewAI — Give Your Crew a Skool Tool",
  "description": "Connect Skool to CrewAI with a custom tool. Wrap the Apify-hosted Skool actor as a BaseTool or @tool, hand it to an Agent, and let your crew approve members, post, and publish courses.",
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
  "mainEntityOfPage": "https://ctala.github.io/skool-api-docs/integrations/skool-crewai/"
}
</script>
