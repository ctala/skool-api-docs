---
title: "Skool API for AI Agents — Claude, GPT, MCP, LangChain (2026)"
description: "Use the Skool API from AI agents. Function-calling specs for Claude and OpenAI, MCP server, LangChain Tool wrapper, idempotency, never-throw contract."
slug: /for/ai-agents
type: persona
primary_keyword: "skool api ai agent"
search_volume_monthly: null
funnel: A
playbook: personas
last_updated: 2026-05-19
canonical: https://ctala.github.io/skool-api-docs/for/ai-agents/
---


> **TL;DR.** Every Skool operation (post, comment, member approval, course publishing, Auto DM update) is one HTTP POST with a structured JSON response. The actor is designed to plug directly into agent loops (Claude tool use, OpenAI function calling, MCP, LangChain) without custom glue code. Never-throw contract = no try/catch around tool calls.

## Why agents should use this actor

Building an AI agent that operates a Skool community without this actor means:

- Maintain Playwright Chromium installation in your agent's runtime
- Handle Skool's cookies + WAF token + weekly `buildId` rotation
- Parse Skool's internal API responses (undocumented, version-dependent)
- Wrap ~30 endpoints across posts/members/classroom/files
- Build a structured-error layer on top of the raw responses

That's a ~3K-line, 50-hour engineering project. Then it breaks weekly when Skool ships.

With the actor: **one HTTP POST**. The actor handles all of that for ~$0.005-$0.01 per call.

## The agent contract — what makes this AI-agent-native

### 1. One action per call

Every operation is a single POST. No multi-step state. Agents that retry get safe semantics for reads; writes are explicitly non-idempotent for creates (you may publish twice) but explicitly idempotent for updates (you can replay `posts:update` or `classroom:updateCourse` safely).

### 2. Never-throw contract

```
{ "success": true, "data": { ... } }
```

or

```
{ "success": false, "errorCode": "WAF_EXPIRED", "errorCategory": "auth", "hint": "Re-run auth:login with email/password and store new cookies", "retryable": true }
```

Agents that branch on `success` don't need exception handling. The `hint` field is designed to be **literally readable by an LLM** — when your agent gets a failure, you pass the `hint` back into the prompt and it knows what to do.

### 3. Idempotency where it matters

| Action | Idempotent? |
|---|---|
| `posts:create` | No — repeat call creates a second post |
| `posts:update` | **Yes** — replay with same params produces same final state |
| `members:approve` | **Yes** — already-approved returns success without side effect |
| `members:batchApprove` | **Yes** — individual results in response |
| `classroom:setBody` | **Yes** — page body becomes the value you sent, replay is safe |
| `classroom:updateCourse` | **Yes** — actor does read-then-write so omitted fields are preserved |
| `posts:createComment` | No |
| `files:uploadImage` | No (each call uploads a new copy) |
| `groups:setAutoDM` | **Yes** |

Agents that mark `idempotent: true` on Claude tool definitions or `parallel: true` on multi-action plans can use this table to decide.

### 4. Structured `params` per action

Every action documents required and optional params explicitly. See [actions reference](../docs/actions.md). For agents, this means the function-calling schema can be generated mechanically — no free-form text fields.

## Claude tool definition (Anthropic)

```python
SKOOL_TOOL = {
    "name": "skool_action",
    "description": "Perform a read or write action against a Skool community via the Apify-hosted Skool All-in-One API actor. Every action returns either {success: true, data: ...} or {success: false, errorCode, hint}.",
    "input_schema": {
        "type": "object",
        "properties": {
            "action": {
                "type": "string",
                "enum": [
                    "auth:login", "system:health", "system:debug",
                    "posts:list", "posts:filter", "posts:get", "posts:create", "posts:update", "posts:delete",
                    "posts:createComment", "posts:getComments", "posts:getCommentsFull", "posts:pin", "posts:unpin", "posts:vote",
                    "members:list", "members:pending", "members:approve", "members:reject", "members:ban", "members:batchApprove",
                    "events:list", "events:upcoming",
                    "classroom:listCourses", "classroom:getTree", "classroom:createCourse", "classroom:createFolder",
                    "classroom:createPage", "classroom:setBody", "classroom:updateCourse", "classroom:deleteUnit", "classroom:updateResources",
                    "files:uploadImage", "files:uploadFile",
                    "groups:get", "groups:setAutoDM"
                ],
                "description": "Action to perform (36 actions total, actor v0.3.25)"
            },
            "params": {
                "type": "object",
                "description": "Action-specific parameters. See https://github.com/ctala/skool-api-docs/blob/main/docs/actions.md"
            }
        },
        "required": ["action", "params"]
    }
}
```

When Claude calls this tool, your handler issues the HTTP POST with the agent's pre-loaded `cookies` and `groupSlug`, then returns the response back to Claude verbatim. Claude can then read the `success` and `hint` fields and decide what to do next.

## OpenAI function calling

```python
SKOOL_FUNCTION = {
    "type": "function",
    "function": {
        "name": "skool_action",
        "description": "Perform a Skool action via the Apify-hosted Skool All-in-One API actor. Returns structured success/failure response.",
        "parameters": {
            "type": "object",
            "properties": {
                "action": {"type": "string"},
                "params": {"type": "object"}
            },
            "required": ["action", "params"]
        }
    }
}
```

Same shape, just translated to OpenAI's function format.

## MCP server (Model Context Protocol)

The actor exposes natively as an MCP tool. Each action becomes an MCP tool with its own schema. Discovery happens at MCP server boot — your agent client lists tools and calls them with structured params.

See [Skool MCP server](../integrations/skool-mcp-server.md) for the full setup, including:

- Tool listing
- Auth flow (one-time `auth:login`, cookies in MCP server config)
- Error mapping to MCP error codes
- Running locally vs hosted on mcp.apify.com

## LangChain Tool wrapper

```python
from langchain.tools import StructuredTool
from pydantic import BaseModel, Field
import requests

class SkoolActionInput(BaseModel):
    action: str = Field(description="Skool action, e.g. 'posts:create'")
    params: dict = Field(description="Action-specific params")

def skool_action(action: str, params: dict, cookies: str, group_slug: str, apify_token: str) -> dict:
    resp = requests.post(
        f"https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token={apify_token}&build=latest&timeout=90",
        json={"action": action, "cookies": cookies, "groupSlug": group_slug, "params": params},
        timeout=120
    )
    data = resp.json()
    # actor returns a list; first item is the result
    return data[0] if isinstance(data, list) and data else data

skool_tool = StructuredTool.from_function(
    func=skool_action,
    name="skool_action",
    description="Perform a Skool action via Apify. See https://github.com/ctala/skool-api-docs/blob/main/docs/actions.md",
    args_schema=SkoolActionInput,
)
```

Add `skool_tool` to your LangChain agent's tool list. Agent now operates Skool.

## Agent loop pattern — recommended

```
┌───────────────────────────────────────────────────────────────┐
│  User intent (e.g. "approve the latest 5 applicants")         │
│           │                                                    │
│           ▼                                                    │
│  LLM plans: members:pending → for each, members:approve        │
│           │                                                    │
│           ▼                                                    │
│  Tool call: skool_action(action="members:pending", params={})  │
│           │                                                    │
│           ▼                                                    │
│  Response: {success: true, data: [m1, m2, m3, m4, m5, ...]}    │
│           │                                                    │
│           ▼                                                    │
│  LLM extracts memberId for each, plans batchApprove            │
│           │                                                    │
│           ▼                                                    │
│  Tool call: skool_action(action="members:batchApprove",        │
│                          params={memberIds: [m1, m2, m3, m4, m5]})│
│           │                                                    │
│           ▼                                                    │
│  Response: per-item results                                    │
│           │                                                    │
│           ▼                                                    │
│  LLM summarizes for user.                                     │
└───────────────────────────────────────────────────────────────┘
```

Note: agents should use `memberId`, not `id`. Confusing the two is the #1 silent bug in member-management automations (returns 404 with no clear explanation).

## Error handling pattern for agents

When a tool call returns `{success: false}`, pass the entire response back into the prompt. The `hint` field is designed to be acted on:

| `errorCode` | `hint` | Agent action |
|---|---|---|
| `WAF_EXPIRED` | "Re-run auth:login with email/password and store new cookies" | Call `auth:login`, update stored cookies, retry |
| `MISSING_CATEGORY` | "Fetch label_options via groups:get and include labelId in params" | Call `groups:get`, ask user for category or pick first, retry |
| `TITLE_TOO_LONG` | "Trim the title — max 50 UTF-16 chars" | Trim, retry |
| `RATE_LIMIT` | "Wait 60s before retrying — Skool limits writes" | Sleep 60s, retry |
| `MEMBER_NOT_FOUND` | "Use memberId (from members:pending), not id" | Re-fetch with `members:pending`, use `memberId` field, retry |

LLMs handle this well — give them the structured response and they self-correct in 1-2 steps.

## Pre-flight checks for destructive actions

Before any agent calls `posts:delete`, `members:ban`, or `classroom:deleteUnit`:

1. List what will be affected (`classroom:getTree`, `members:list`, etc.)
2. Show the user
3. Wait for explicit confirmation
4. Then act

This is enforced in [the Claude Code skill](../skills/claude-code/skool-actor/SKILL.md). Agents should not assume "delete all" without showing scope.

## Real-world agents using this actor

Per Apify analytics (May 2026), incoming traffic includes:

- `claude.ai` — direct discovery by Claude users looking for Skool automation
- `mcp.apify.com` — MCP server marketplace
- `n8n.io` — workflow template hub
- `console.apify.com` — Apify users browsing actors

This page exists to make that discovery cleaner — when an agent (or the human directing it) lands on the actor, they should know exactly how to integrate it.

## Common questions

### Can an agent run unsupervised long-term?

Yes for read actions (member lists, post lists, course trees). For writes, recommend a human approval step (Telegram bot, Slack DM) for the first 100 operations until you trust the agent's tone and judgment. After that, fully autonomous is fine for low-stakes operations (auto-approve members, schedule posts). High-stakes operations (ban, delete) should keep a human approval gate.

### How does the agent handle cookies expiring?

The actor returns `{success: false, errorCode: "WAF_EXPIRED"}` when cookies age out. Your agent re-runs `auth:login` with stored email/password, updates the cookies in its credential store, retries the original action. This takes ~10 seconds (one Playwright login) and happens roughly every 3.5 days.

### What about Skool's own rate limits?

Skool caps writes at ~25/min globally. The actor queues internally — don't add your own retry loop. If your agent generates more writes than that, batch them or wait. For `members:approve` specifically, use `members:batchApprove` which Skool handles server-side and bypasses the per-call limit.

## Related

- [AI Agents integration guide](../docs/agents.md) — full Claude/OpenAI/Gemini function specs
- [Skool MCP server](../integrations/skool-mcp-server.md)
- [Skool + Claude](../integrations/skool-claude.md)
- [Claude Code Skill](../skills/claude-code/skool-actor/SKILL.md) — drop into your `.claude/skills/`

---

## Plug this into your agent today

[**→ Open the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=persona&utm_campaign=ai-agents&fpr=cristian)

- One HTTP POST per action
- Never-throw contract → no try/catch needed
- `hint` field is LLM-readable error recovery
- Pay-per-event (~$0.005-$0.01 per call)
- Battle-tested in production

*No Skool community to automate yet? [Launch one in 10 minutes](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "TechArticle",
  "headline": "Skool API for AI Agents",
  "description": "Use the Skool API from AI agents. Function-calling specs for Claude and OpenAI, MCP server, LangChain Tool wrapper, idempotency, never-throw contract.",
  "datePublished": "2026-05-19",
  "author": {"@type": "Person", "name": "Cristian Tala", "url": "https://cristiantala.com"}
}
</script>
