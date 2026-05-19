---
title: "Skool MCP Server — Production Setup for AI Agents (2026)"
description: "Run a production MCP server for Skool. Tool listing, auth flow, error handling, deployment to Docker/Cloud Run. Apify-backed."
slug: /integrations/skool-mcp-server
type: integration
primary_keyword: "skool mcp server"
search_volume_monthly: 10
funnel: A
playbook: integrations
last_updated: 2026-05-19
canonical: https://github.com/ctala/skool-api-docs/blob/main/integrations/skool-mcp-server.md
---


> **Quick reference (TL;DR for agents)**
> - **Use case:** Run a persistent MCP server that exposes the Skool API as tools for AI agents (Claude Desktop, Cursor, Cline, hosted agents).
> - **Backend:** [Apify-hosted Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-mcp-server).
> - **Two deployment modes:** local stdio (per-user) or remote HTTP/SSE (shared).
> - **Cost:** ~$0.005-$0.01 per tool call (Apify pay-per-event).

For a quick intro, see [Skool MCP (concepts and quick setup)](skool-mcp.md). This page is the production deployment guide.

## Architecture

```
AI client                    MCP server                 Apify actor             Skool
─────────                    ──────────                 ───────────             ─────
[Claude Desktop]
[Cursor]            ◄─ stdio ─►  [skool-mcp]  ─POST─►  [run-sync-get-     ─►   [api.skool.com]
[Cline]              or HTTP                            dataset-items]
                                       │                       │                     │
                                       │                       ├── api.skool.com ────┤
                                       │                       │     (cookies +      │
                                       │                       │     WAF + buildId)  │
                                       │                       │                     │
                                       ◄──────  result  ────────────────────────────┘
```

The MCP server is a thin proxy. All Skool complexity stays in the actor — your server just maps MCP tool calls to actor `action` strings.

## Full server implementation — Python

```python
# server.py — Skool MCP server (stdio mode)
import os
import asyncio
import logging
import httpx
import json
from typing import Any
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("skool-mcp")

APIFY_TOKEN = os.environ["APIFY_TOKEN"]
SKOOL_EMAIL = os.environ.get("SKOOL_EMAIL")          # for cookie rotation
SKOOL_PASSWORD = os.environ.get("SKOOL_PASSWORD")
GROUP_SLUG = os.environ["SKOOL_GROUP_SLUG"]

_cookies = os.environ.get("SKOOL_COOKIES", "")        # mutable, rotates on WAF_EXPIRED

ACTOR_URL = (
    "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/"
    "run-sync-get-dataset-items"
    f"?token={APIFY_TOKEN}&build=latest&timeout=90"
)

# ---- TOOL CATALOG ----
TOOLS = [
    Tool(
        name="skool_posts_list",
        description="List posts in the Skool community feed. Optional filters: page, sort, limit, since, until, unanswered, labelId.",
        inputSchema={
            "type": "object",
            "properties": {
                "page": {"type": "integer"},
                "limit": {"type": "integer"},
                "sort": {"type": "string"},
                "since": {"type": "string", "format": "date-time"},
                "labelId": {"type": "string"}
            }
        }
    ),
    Tool(
        name="skool_posts_create",
        description="Create a new top-level post. Skool ignores HTML/markdown — pass plain text.",
        inputSchema={
            "type": "object",
            "properties": {
                "title": {"type": "string"},
                "content": {"type": "string"},
                "labelId": {"type": "string"}
            },
            "required": ["title", "content"]
        }
    ),
    Tool(
        name="skool_posts_create_comment",
        description=(
            "Reply to a post or comment. For top-level comment: rootId == parentId == postId. "
            "For nested reply: rootId == postId (the post), parentId == commentId (the comment you're replying to)."
        ),
        inputSchema={
            "type": "object",
            "properties": {
                "rootId": {"type": "string"},
                "parentId": {"type": "string"},
                "content": {"type": "string"}
            },
            "required": ["rootId", "parentId", "content"]
        }
    ),
    Tool(
        name="skool_members_pending",
        description="List pending member applications. Returns memberId for each.",
        inputSchema={"type": "object", "properties": {}}
    ),
    Tool(
        name="skool_members_approve",
        description="Approve a pending member by memberId. Note: memberId from members:pending, NOT user id.",
        inputSchema={
            "type": "object",
            "properties": {"memberId": {"type": "string"}},
            "required": ["memberId"]
        }
    ),
    Tool(
        name="skool_members_reject",
        description="Reject a pending member by memberId.",
        inputSchema={
            "type": "object",
            "properties": {"memberId": {"type": "string"}},
            "required": ["memberId"]
        }
    ),
    Tool(
        name="skool_members_batch_approve",
        description="Approve multiple pending members in one call. Bypasses the per-call rate limit because Skool handles batch server-side.",
        inputSchema={
            "type": "object",
            "properties": {"memberIds": {"type": "array", "items": {"type": "string"}}},
            "required": ["memberIds"]
        }
    ),
    Tool(
        name="skool_classroom_list_courses",
        description="List all courses in the community classroom.",
        inputSchema={"type": "object", "properties": {}}
    ),
    Tool(
        name="skool_classroom_get_tree",
        description="Get the full tree (folders + pages) of a specific course.",
        inputSchema={
            "type": "object",
            "properties": {"courseId": {"type": "string"}},
            "required": ["courseId"]
        }
    ),
    Tool(
        name="skool_classroom_create_page",
        description="Create a new page inside a course or folder.",
        inputSchema={
            "type": "object",
            "properties": {
                "courseId": {"type": "string"},
                "parentId": {"type": "string", "description": "Course id for top-level page, folder id for nested"},
                "title": {"type": "string", "maxLength": 50}
            },
            "required": ["courseId", "parentId", "title"]
        }
    ),
    Tool(
        name="skool_classroom_set_body",
        description="Set the body of a course page. Markdown auto-converts to TipTap (Skool's internal format).",
        inputSchema={
            "type": "object",
            "properties": {
                "pageId": {"type": "string"},
                "title": {"type": "string"},
                "bodyMarkdown": {"type": "string"}
            },
            "required": ["pageId", "title", "bodyMarkdown"]
        }
    ),
    Tool(
        name="skool_groups_set_auto_dm",
        description="Set the Auto DM message new members receive on join. Max 300 chars. Tokens: #NAME#, #GROUPNAME#.",
        inputSchema={
            "type": "object",
            "properties": {"message": {"type": "string", "maxLength": 300}},
            "required": ["message"]
        }
    ),
]

ACTION_MAP = {
    "skool_posts_list": "posts:list",
    "skool_posts_create": "posts:create",
    "skool_posts_create_comment": "posts:createComment",
    "skool_members_pending": "members:pending",
    "skool_members_approve": "members:approve",
    "skool_members_reject": "members:reject",
    "skool_members_batch_approve": "members:batchApprove",
    "skool_classroom_list_courses": "classroom:listCourses",
    "skool_classroom_get_tree": "classroom:getTree",
    "skool_classroom_create_page": "classroom:createPage",
    "skool_classroom_set_body": "classroom:setBody",
    "skool_groups_set_auto_dm": "groups:setAutoDM",
}

async def rotate_cookies() -> str:
    """Call auth:login and return new cookies. Used when WAF_EXPIRED."""
    global _cookies
    if not SKOOL_EMAIL or not SKOOL_PASSWORD:
        raise RuntimeError("SKOOL_EMAIL/SKOOL_PASSWORD not set — cannot auto-rotate cookies")
    async with httpx.AsyncClient(timeout=120) as client:
        resp = await client.post(ACTOR_URL, json={
            "action": "auth:login",
            "email": SKOOL_EMAIL,
            "password": SKOOL_PASSWORD,
            "groupSlug": GROUP_SLUG,
        })
        data = resp.json()
        result = data[0] if isinstance(data, list) else data
        if not result.get("success"):
            raise RuntimeError(f"auth:login failed: {result}")
        _cookies = result["cookies"]
        log.info("Rotated Skool cookies (expires %s)", result.get("expiresAt"))
        return _cookies

async def call_actor(action: str, params: dict) -> dict:
    global _cookies
    payload = {"action": action, "cookies": _cookies, "groupSlug": GROUP_SLUG, "params": params}
    async with httpx.AsyncClient(timeout=120) as client:
        resp = await client.post(ACTOR_URL, json=payload)
        data = resp.json()
        result = data[0] if isinstance(data, list) else data
        if not result.get("success") and result.get("errorCode") == "WAF_EXPIRED":
            log.info("Cookies expired — rotating")
            await rotate_cookies()
            payload["cookies"] = _cookies
            resp = await client.post(ACTOR_URL, json=payload)
            data = resp.json()
            result = data[0] if isinstance(data, list) else data
        return result

app = Server("skool")

@app.list_tools()
async def list_tools():
    return TOOLS

@app.call_tool()
async def call_tool(name: str, arguments: dict) -> list[TextContent]:
    action = ACTION_MAP.get(name)
    if not action:
        return [TextContent(type="text", text=json.dumps({"success": False, "error": f"Unknown tool: {name}"}))]
    result = await call_actor(action, arguments)
    return [TextContent(type="text", text=json.dumps(result, indent=2))]

if __name__ == "__main__":
    asyncio.run(stdio_server(app))
```

## Dockerfile

```dockerfile
FROM python:3.11-slim
RUN pip install mcp httpx
COPY server.py /app/server.py
WORKDIR /app
CMD ["python", "server.py"]
```

Build + run:

```bash
docker build -t skool-mcp .
docker run -i --rm \
  -e APIFY_TOKEN=... \
  -e SKOOL_EMAIL=... \
  -e SKOOL_PASSWORD=... \
  -e SKOOL_COOKIES=... \
  -e SKOOL_GROUP_SLUG=... \
  skool-mcp
```

For HTTP/SSE deployment instead of stdio, swap `stdio_server` for an HTTP transport (`mcp.server.sse_server`) and expose port 8000. Deploy to Cloud Run / Fly.io / Railway with `gcloud run deploy` or equivalent.

## Connecting from Claude Desktop

```json
{
  "mcpServers": {
    "skool": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-e", "APIFY_TOKEN=...",
        "-e", "SKOOL_EMAIL=...",
        "-e", "SKOOL_PASSWORD=...",
        "-e", "SKOOL_COOKIES=...",
        "-e", "SKOOL_GROUP_SLUG=...",
        "skool-mcp"
      ]
    }
  }
}
```

## Production gotchas

- **`memberId` vs `user_id`** — tool descriptions explicitly say "memberId, NOT user id". Even with the description, agents occasionally pass the wrong id. Add a server-side check that rejects 32-character `user_id`-looking values when `memberId` is expected.
- **Cookies in env** — rotating cookies in process memory works for a single container instance. For multi-replica deployments (HTTP server behind a load balancer), externalize cookies to Redis or a database so all replicas share state.
- **Tool count limit** — Some MCP clients cap tools at ~30. The full actor surface is ~25 actions, so you're fine, but if you add custom helpers don't blow past 30.
- **Streaming results** — MCP supports streaming for long-running tools. The actor doesn't, so all responses are atomic. Set MCP client `tool_timeout` ≥ 90s for `auth:login`.

## Related

- [Skool MCP (concepts + quick setup)](skool-mcp.md)
- [Skool + Claude](skool-claude.md)
- [Skool for AI agents](../for/ai-agents.md)

---

## Deploy your Skool MCP server today

[**→ Open the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-mcp-server)

Wrap it with the ~150-line MCP server above. Your AI agents get Skool as a native toolset. Pay-per-event (~$0.005-$0.01 per call).

*No Skool community to connect yet? [Launch one in 10 minutes](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{"@context":"https://schema.org","@type":"TechArticle","headline":"Skool MCP Server","datePublished":"2026-05-19","author":{"@type":"Person","name":"Cristian Tala"}}
</script>
