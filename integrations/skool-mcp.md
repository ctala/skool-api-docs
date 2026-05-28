---
title: "Skool MCP — Model Context Protocol Server for Skool (2026)"
description: "Connect Skool to any MCP-compatible AI agent (Claude Desktop, Cursor, Cline). One tool per Skool action: posts, members, classroom, files. Apify-hosted."
slug: /integrations/skool-mcp
type: integration
primary_keyword: "skool mcp"
search_volume_monthly: 10
funnel: A
playbook: integrations
last_updated: 2026-05-19
canonical: https://ctala.github.io/skool-api-docs/integrations/skool-mcp/
---


> **Quick reference (TL;DR for agents)**
> - **What this enables:** Any MCP-compatible AI client (Claude Desktop, Cursor, Cline, Continue) can read AND write to Skool natively as tools.
> - **Implementation:** The [Apify-hosted Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-mcp&fpr=cristian) is exposed as MCP tools via Apify's MCP gateway at `mcp.apify.com`.
> - **Alternative:** Run a local MCP server that proxies the actor — full code below.
> - **Latency:** ~2s per tool call.
> - **Cost:** Apify pay-per-event (~$0.005-$0.01 per call).

## What is MCP and why does Skool need it?

[Model Context Protocol (MCP)](https://modelcontextprotocol.io) is the open standard for connecting AI agents to external tools. Instead of every agent shipping its own way of calling APIs, MCP gives them a unified tool-discovery and invocation protocol.

For Skool: an MCP server exposes every actor action (`posts:create`, `members:approve`, `classroom:setBody`, etc.) as a discrete MCP tool with its own schema. Your AI agent — Claude Desktop, Cursor, Cline — connects to the MCP server, sees the tools, and invokes them with structured params.

This is the cleanest agent integration pattern in 2026. No custom function-calling code per agent. The same MCP server serves Claude Desktop and Cursor and Cline identically.

## Option A — Apify's hosted MCP gateway

Apify hosts every actor as an MCP server at `mcp.apify.com`. The Skool All-in-One API actor is automatically available.

### Setup in Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS) or `%APPDATA%\Claude\claude_desktop_config.json` (Windows):

```json
{
  "mcpServers": {
    "skool": {
      "command": "npx",
      "args": [
        "-y",
        "@apify/actors-mcp-server",
        "--token=YOUR_APIFY_TOKEN",
        "--actors=cristiantala/skool-all-in-one-api"
      ]
    }
  }
}
```

Restart Claude Desktop. The Skool actor's actions appear as tools in your chat.

### Setup in Cursor

Cursor settings → MCP Servers → Add server:

- **Name:** `skool`
- **Command:** `npx -y @apify/actors-mcp-server --token=YOUR_APIFY_TOKEN --actors=cristiantala/skool-all-in-one-api`

## Option B — Run your own MCP server

For more control (custom tool descriptions, batched calls, auth caching), run a local MCP server that proxies the actor.

```python
# skool_mcp.py — minimal MCP server proxying the Skool actor
import os
import asyncio
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent
import httpx, json

APIFY_TOKEN = os.environ["APIFY_TOKEN"]
SKOOL_COOKIES = os.environ["SKOOL_COOKIES"]
GROUP_SLUG = os.environ["SKOOL_GROUP_SLUG"]

app = Server("skool")

# Tool definitions (subset for brevity — add the rest)
TOOLS = [
    Tool(
        name="skool_post_create",
        description="Create a new top-level post in the Skool community feed.",
        inputSchema={
            "type": "object",
            "properties": {
                "title": {"type": "string", "maxLength": 100},
                "content": {"type": "string"},
                "labelId": {"type": "string", "description": "Optional category id from groups:get"}
            },
            "required": ["title", "content"]
        }
    ),
    Tool(
        name="skool_members_pending",
        description="List members in the approval queue.",
        inputSchema={"type": "object", "properties": {}}
    ),
    Tool(
        name="skool_members_approve",
        description="Approve a pending member by memberId (from skool_members_pending). Note: memberId, NOT user id.",
        inputSchema={
            "type": "object",
            "properties": {"memberId": {"type": "string"}},
            "required": ["memberId"]
        }
    ),
    # ... add all other actor actions
]

@app.list_tools()
async def list_tools():
    return TOOLS

@app.call_tool()
async def call_tool(name: str, arguments: dict):
    action_map = {
        "skool_post_create": "posts:create",
        "skool_members_pending": "members:pending",
        "skool_members_approve": "members:approve",
    }
    action = action_map.get(name)
    if not action:
        return [TextContent(type="text", text=f"Unknown tool: {name}")]

    async with httpx.AsyncClient(timeout=120) as client:
        resp = await client.post(
            f"https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token={APIFY_TOKEN}&build=latest&timeout=90",
            json={"action": action, "cookies": SKOOL_COOKIES, "groupSlug": GROUP_SLUG, "params": arguments}
        )
        data = resp.json()
        result = data[0] if isinstance(data, list) and data else data
        return [TextContent(type="text", text=json.dumps(result, indent=2))]

if __name__ == "__main__":
    asyncio.run(stdio_server(app))
```

Run it from your MCP client config:

```json
{
  "mcpServers": {
    "skool": {
      "command": "python",
      "args": ["/absolute/path/to/skool_mcp.py"],
      "env": {
        "APIFY_TOKEN": "...",
        "SKOOL_COOKIES": "...",
        "SKOOL_GROUP_SLUG": "..."
      }
    }
  }
}
```

## How an agent uses the MCP tools

Once the MCP server is connected, your AI agent (Claude Desktop, Cursor, etc.) sees Skool actions as native tools. Example session:

> **User:** Approve all the pending applicants who mentioned "AI agent builder" in their LinkedIn.
>
> **Agent (Claude):** I'll list pending applicants and check each one's LinkedIn metadata.
>
> [tool: skool_members_pending]
>
> *Returns list of pending members with their LinkedIn URLs.*
>
> **Agent:** I found 4 applicants. Of those, 2 have "AI agent" in their LinkedIn title. I'll approve them.
>
> [tool: skool_members_approve { memberId: "..." }]
> [tool: skool_members_approve { memberId: "..." }]
>
> **Agent:** Approved 2 of 4. Returning the other 2 for manual review since "AI agent builder" wasn't explicit in their profile.

The agent reasons about which tools to call and chains them. The MCP server makes the actor look native.

## Cookie rotation in MCP

MCP server config holds the cookies in `env`. When they expire (~3.5 days), the actor returns `WAF_EXPIRED`. Your MCP server should:

1. Catch the error
2. Run an `auth:login` call (env vars must include `SKOOL_EMAIL` + `SKOOL_PASSWORD`)
3. Update the in-memory `SKOOL_COOKIES`
4. Retry the original tool call
5. Optionally persist new cookies to disk

For unattended use, this auto-rotation is essential.

## Production gotchas

- **Tool name conventions:** MCP tools should use `snake_case_with_namespace` (`skool_posts_create`, not `posts:create`). Map them in your handler.
- **Schema validation:** MCP clients validate input against the tool's `inputSchema` before calling. If Skool rejects your params, the error is in your schema, not the actor.
- **Streaming responses:** MCP supports streaming, the actor doesn't. Wait for full response before returning to the MCP client.
- **Long-running calls:** `auth:login` takes ~10s. If your MCP client has a tool-call timeout, configure it ≥30s.

## Related

- [Skool MCP server — production setup](skool-mcp-server.md)
- [Skool + Claude](skool-claude.md)
- [Skool for AI agents](../for/ai-agents.md)

---

## Connect Skool to your AI agent today

[**→ Open the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-mcp&fpr=cristian)

Native MCP via `mcp.apify.com` or run your own server with the code above. Pay-per-event (~$0.005-$0.01 per tool call).

*No Skool community yet? [Launch one in 10 minutes](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{"@context":"https://schema.org","@type":"TechArticle","headline":"Skool MCP — Model Context Protocol for Skool","datePublished":"2026-05-19","author":{"@type":"Person","name":"Cristian Tala"}}
</script>
