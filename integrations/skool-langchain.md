---
title: "Skool + LangChain — Use the Skool API in LangChain Agents (2026)"
description: "Use the Skool API as a LangChain Tool. Drop-in StructuredTool wrapper, agent executor patterns, async, error handling."
slug: /integrations/skool-langchain
type: integration
primary_keyword: "skool langchain"
search_volume_monthly: null
funnel: A
playbook: integrations
last_updated: 2026-05-19
canonical: https://github.com/ctala/skool-api-docs/blob/main/integrations/skool-langchain.md
---

# Skool + LangChain

> **Quick reference (TL;DR for agents)**
> - **What this enables:** Any LangChain agent (LLM-agnostic — works with Claude, GPT, Gemini, local models) can read and write to Skool as a Tool.
> - **Method:** `StructuredTool` wraps a single function that POSTs to the [Apify-hosted Skool actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-langchain).
> - **Async-ready:** use `StructuredTool` with `coroutine=` for high-throughput agents.

## The Tool — minimal

```python
from langchain.tools import StructuredTool
from pydantic import BaseModel, Field
import requests, os

class SkoolActionInput(BaseModel):
    action: str = Field(description="Skool action, e.g. 'posts:create', 'members:approve'. See https://github.com/ctala/skool-api-docs/blob/main/docs/actions.md")
    params: dict = Field(default_factory=dict, description="Action-specific params")

def skool_action(action: str, params: dict) -> dict:
    """Call the Apify-hosted Skool actor. Returns structured success/failure."""
    resp = requests.post(
        f"https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items"
        f"?token={os.environ['APIFY_TOKEN']}&build=latest&timeout=90",
        json={
            "action": action,
            "cookies": os.environ["SKOOL_COOKIES"],
            "groupSlug": os.environ["SKOOL_GROUP_SLUG"],
            "params": params or {},
        },
        timeout=120
    )
    resp.raise_for_status()
    data = resp.json()
    return data[0] if isinstance(data, list) and data else data

skool_tool = StructuredTool.from_function(
    func=skool_action,
    name="skool_action",
    description=(
        "Perform a read or write operation on a Skool community. "
        "Returns {success: true, data: ...} or {success: false, errorCode, hint}. "
        "On failure, read the 'hint' field — it tells you what to do next. "
        "For comment replies: rootId == postId, parentId == commentId (NOT postId). "
        "For member operations: use memberId (from members:pending), NOT user id."
    ),
    args_schema=SkoolActionInput,
)
```

## Using in an Agent

```python
from langchain.agents import AgentExecutor, create_tool_calling_agent
from langchain_anthropic import ChatAnthropic
from langchain.prompts import ChatPromptTemplate

llm = ChatAnthropic(model="claude-opus-4-7", anthropic_api_key=os.environ["ANTHROPIC_API_KEY"])

prompt = ChatPromptTemplate.from_messages([
    ("system", "You operate a Skool community via the skool_action tool. Be precise with params."),
    ("user", "{input}"),
    ("placeholder", "{agent_scratchpad}"),
])

agent = create_tool_calling_agent(llm, [skool_tool], prompt)
executor = AgentExecutor(agent=agent, tools=[skool_tool], verbose=True, max_iterations=10)

result = executor.invoke({
    "input": "Approve the latest 3 pending members. Reply to me with a one-line summary of each."
})
print(result["output"])
```

## Async version

```python
import httpx
from langchain.tools import StructuredTool

async def skool_action_async(action: str, params: dict) -> dict:
    async with httpx.AsyncClient(timeout=120) as client:
        resp = await client.post(
            f"https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items"
            f"?token={os.environ['APIFY_TOKEN']}&build=latest&timeout=90",
            json={"action": action, "cookies": os.environ["SKOOL_COOKIES"], "groupSlug": os.environ["SKOOL_GROUP_SLUG"], "params": params or {}}
        )
        data = resp.json()
        return data[0] if isinstance(data, list) and data else data

skool_tool_async = StructuredTool.from_function(
    func=skool_action,             # sync fallback
    coroutine=skool_action_async,  # async path
    name="skool_action",
    description="...",
    args_schema=SkoolActionInput,
)
```

LangChain's agent executor calls the async version automatically when running with `ainvoke`.

## Per-action tools (alternative pattern)

Instead of one generic `skool_action` tool, expose each action as a separate Tool. Slightly more tokens used per agent invocation (more tool schemas) but the LLM has higher confidence picking the right one.

```python
def make_action_tool(action: str, description: str, params_schema):
    def fn(**kwargs) -> dict:
        return skool_action(action, kwargs)
    return StructuredTool.from_function(
        func=fn,
        name=action.replace(":", "_"),
        description=description,
        args_schema=params_schema,
    )

class PostsCreateInput(BaseModel):
    title: str
    content: str
    labelId: str | None = None

posts_create_tool = make_action_tool(
    "posts:create",
    "Create a new top-level post in the Skool feed. Plain text only (no HTML/markdown).",
    PostsCreateInput,
)

# ... repeat for ~25 actions
```

Use when your agent's primary use case is a small subset of actions (e.g. just member approval). Skip when the agent needs the full surface.

## Auto-rotate cookies on `WAF_EXPIRED`

Wrap the base call:

```python
def skool_action_with_retry(action: str, params: dict) -> dict:
    result = skool_action(action, params)
    if not result.get("success") and result.get("errorCode") == "WAF_EXPIRED":
        # Rotate cookies
        login = skool_action("auth:login", {
            "email": os.environ["SKOOL_EMAIL"],
            "password": os.environ["SKOOL_PASSWORD"],
            "groupSlug": os.environ["SKOOL_GROUP_SLUG"],
        })
        if login.get("success"):
            os.environ["SKOOL_COOKIES"] = login["cookies"]
            return skool_action(action, params)
    return result

skool_tool = StructuredTool.from_function(func=skool_action_with_retry, ...)
```

Now the agent doesn't see `WAF_EXPIRED` errors — the wrapper handles them transparently.

## LangGraph pattern

For more complex agent state machines, use LangGraph:

```python
from langgraph.graph import StateGraph, END
from typing import TypedDict, list

class AgentState(TypedDict):
    messages: list
    last_skool_result: dict

def agent_node(state):
    response = llm.invoke(state["messages"])
    state["messages"].append(response)
    return state

def tool_node(state):
    last = state["messages"][-1]
    if last.tool_calls:
        for tc in last.tool_calls:
            result = skool_action(tc.args["action"], tc.args["params"])
            state["messages"].append({"role": "tool", "content": str(result), "tool_call_id": tc.id})
            state["last_skool_result"] = result
    return state

def should_continue(state):
    last = state["messages"][-1]
    return "tool" if last.tool_calls else END

workflow = StateGraph(AgentState)
workflow.add_node("agent", agent_node)
workflow.add_node("tool", tool_node)
workflow.set_entry_point("agent")
workflow.add_conditional_edges("agent", should_continue, {"tool": "tool", END: END})
workflow.add_edge("tool", "agent")
graph = workflow.compile()
```

## Related

- [Skool + Claude](skool-claude.md)
- [Skool + GPT](skool-gpt.md)
- [Skool for AI agents](../for/ai-agents.md)
- [Skool + Python](skool-python.md)

---

## Add Skool to your LangChain agent today

[**→ Open the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-langchain)

One `StructuredTool` wraps the entire Skool admin surface. Works with Claude, GPT, Gemini, local models. Pay-per-event (~$0.005-$0.01 per call).

*No Skool community yet? [Launch one in 10 minutes](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{"@context":"https://schema.org","@type":"TechArticle","headline":"Skool + LangChain","datePublished":"2026-05-19","author":{"@type":"Person","name":"Cristian Tala"}}
</script>
