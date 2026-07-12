---
title: "Use the Skool API as an MCP tool for Claude, Cursor & Cline"
description: "Expose all 33 Skool API actions to any MCP client — approve members, post and audit threads from Claude Desktop, Cursor or Cline with zero custom code."
slug: /recipes/use-skool-api-as-mcp-tool
type: recipe
funnel: A
section: Recipes
last_updated: 2026-07-12
render_with_liquid: false
---

# Use the Skool API as MCP tool for Claude / Cursor / Cline

**Use case**: You want your AI agent (Claude Desktop, Cursor, Cline, or any MCP client) to operate your Skool community directly — approve members, post content, audit threads — without writing custom integration code. Apify exposes any public actor as a Model Context Protocol server, so you get all 33 Skool API actions as discoverable AI tools with zero setup beyond config.

## What is MCP?

Model Context Protocol is the standard that lets LLMs discover and call tools at runtime. Anthropic introduced it in late 2025 and the ecosystem grew fast in 2026 — Claude Desktop, Cursor, Cline, Continue, and most major AI dev tools support MCP servers out of the box.

Instead of writing a function-calling schema for each API you want your AI to use, you just point the AI at an MCP server URL and it auto-discovers what tools are available.

## Why MCP for the Skool API?

- **Single config**: paste one URL into your MCP client config, get all 33 Skool actions as tools
- **No code**: the agent picks the right action based on user request, no manual mapping
- **Same pricing**: pay-per-event from Apify ($0.005-$0.05 per call), publishers earn the same as direct API runs
- **Hosted by Apify**: no MCP server to maintain on your side

## Setup for Claude Desktop

### 1. Locate your Claude Desktop config

| OS | Path |
|---|---|
| macOS | `~/Library/Application Support/Claude/claude_desktop_config.json` |
| Windows | `%APPDATA%\Claude\claude_desktop_config.json` |
| Linux | `~/.config/Claude/claude_desktop_config.json` |

### 2. Add the Skool API MCP server

```json
{
  "mcpServers": {
    "skool-api": {
      "command": "npx",
      "args": [
        "-y",
        "@apify/actors-mcp-server",
        "--actors",
        "cristiantala/skool-all-in-one-api"
      ],
      "env": {
        "APIFY_TOKEN": "your_apify_token_here"
      }
    }
  }
}
```

Get your Apify token from [console.apify.com/account/integrations](https://console.apify.com/sign-up?fpr=cristian).

### 3. Restart Claude Desktop

The MCP server starts automatically when Claude launches. You'll see a small hammer icon in the input box indicating tools are available.

### 4. Try it

In Claude Desktop, ask:

> *"Approve all pending members in my Skool community `cagala-aprende-repite` whose application mentions they're founders. Reject the ones that look like spam."*

Claude will:
1. Call `members:pending` to list applicants
2. Review each `whyJoin` field
3. Call `members:approve` or `members:reject` for each one
4. Report back with summary

You'll be prompted to confirm before each write action (Claude Desktop default behavior for MCP tools).

## Setup for Cursor

Cursor uses the same MCP standard:

1. Open Cursor Settings → Features → MCP Servers
2. Click "Add new MCP server"
3. Name: `skool-api`
4. Type: `stdio`
5. Command:
   ```
   npx -y @apify/actors-mcp-server --actors cristiantala/skool-all-in-one-api
   ```
6. Environment: `APIFY_TOKEN=your_token`
7. Save and restart Cursor

## Setup for Cline (VSCode extension)

1. Open Cline panel in VSCode
2. Settings icon → MCP Servers
3. Add server with the same JSON config as Claude Desktop above
4. Refresh Cline → tools appear

## Alternative: Hosted MCP endpoint (no local install)

If you don't want to install anything locally, Apify also exposes a remote MCP endpoint:

```
https://mcp.apify.com?tools=cristiantala/skool-all-in-one-api&token=YOUR_TOKEN
```

This works for any MCP client that supports HTTP transports (Anthropic's web client, custom integrations).

## Example prompts that work well

**Audit your community**:
> "Find the 5 most active members in `my-community` based on posts in the last 30 days. Tell me who they are and what topics they post about."

**Bulk operations**:
> "Approve all pending members in `my-community` who joined in the last 24h."

**Content management**:
> "Create a post in `my-community` titled 'Weekly check-in' with this content: [text]. Pin it to the top."

**Course publishing**:
> "Take this markdown file [paste content] and publish it as a new lesson in the 'Welcome' course of `my-community`."

**Member outreach**:
> "List members of `my-community` who joined more than 30 days ago and haven't posted yet. I want to send them a personalized DM (just show me the list, don't message them)."

## Caveats

- **Confirm before destructive actions**: Claude Desktop / Cursor will ask for confirmation on writes (approve, ban, delete). Don't disable this.
- **Cookies still expire**: the agent will get a `WAF_EXPIRED` error every ~3.5 days. You'll need to re-run `auth:login` manually and update the cached cookies, or ask the agent to do it (it has access to that action too).
- **Rate limits apply**: ~60 reads/min, ~30 writes/min from Skool's side. If the agent tries to do bulk operations on hundreds of items, it'll pace itself.
- **You're responsible**: MCP gives the agent full read+write power. If you have admin rights in the community, the agent can do anything you can do. Use with care.

## Pricing

Same as any other Apify actor invocation. Each MCP tool call counts as one actor run with pay-per-event billing:

- Read operations: ~$0.01 actor start + $0.005 per result returned
- Write operations: + $0.01 per write
- Scrape operations (`posts:getCommentsFull`): + $0.05

Typical "approve 10 pending members" run via MCP: ~$0.12.

## Related

- [Getting Started](../docs/getting-started.md) — first call, auth flow
- [AI Agents integration](../docs/agents.md) — also covers direct function-calling (without MCP)
- [Audit a long welcome thread](audit-welcome-thread-with-getcommentsfull.md) — useful MCP prompt

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "HowTo",
  "name": "Use the Skool API as an MCP tool for Claude, Cursor and Cline",
  "description": "Expose all 33 Skool API actions to any MCP client so Claude Desktop, Cursor or Cline can approve members, post and audit threads with zero custom code.",
  "totalTime": "PT5M",
  "tool": [
    {"@type": "HowToTool", "name": "Apify"},
    {"@type": "HowToTool", "name": "MCP client (Claude Desktop / Cursor / Cline)"}
  ],
  "step": [
    {"@type": "HowToStep", "name": "Locate your MCP client config", "text": "Open the config file for Claude Desktop, Cursor or Cline. Paths differ by operating system and client."},
    {"@type": "HowToStep", "name": "Add the Skool API MCP server", "text": "Add an mcpServers entry that runs the Apify actors-mcp-server with the cristiantala/skool-all-in-one-api actor and your APIFY_TOKEN."},
    {"@type": "HowToStep", "name": "Restart the client", "text": "Restart the MCP client so it launches the server and discovers all 33 Skool actions as tools."},
    {"@type": "HowToStep", "name": "Prompt the agent", "text": "Ask the agent in natural language to approve members, post content or audit threads, confirming before each write action."}
  ]
}
</script>
