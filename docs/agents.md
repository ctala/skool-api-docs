# AI Agents Integration

Use the Skool All-in-One API actor as a tool for AI agents. Includes function-calling specs (Claude / OpenAI / Gemini), MCP server pattern, LangChain Tool definition, Claude Code Skill, and example agent loops.

The actor's response shape is **deliberately agent-friendly**: structured `{success, errorCode, hint}` payloads let an LLM self-correct without wrapper logic. If a call fails, the `hint` field tells the model what to do next.

## Quick comparison

| Stack | Method | Where to plug it |
|---|---|---|
| **Claude tool use** (function calling) | Function definition | Anthropic Messages API `tools` |
| **OpenAI function calling** | Tool definition | Chat Completions / Assistants API `tools` |
| **Gemini function calling** | Function declaration | `generateContent` `tools` |
| **LangChain** | `Tool` class | Add to your agent's tool list |
| **Claude Code** | Skill | `.claude/skills/skool-actor/SKILL.md` ([example](#claude-code-skill)) |
| **MCP server** | Wrap as MCP tool | Self-hosted MCP server proxying to Apify |
| **OpenClaw / Nyx** | Skill | OpenClaw skill format |

## Pattern: one tool per action

The cleanest pattern is to expose **one tool per actor action**: `skool_posts_create`, `skool_members_approve`, `skool_classroom_create_course`, etc. The LLM picks the right one. Don't try to wrap everything in a single `skool_call(action, params)` tool — LLMs route worse without per-action schemas.

## Anthropic Claude — tool definitions

```json
{
  "name": "skool_members_pending",
  "description": "List Skool community members awaiting approval. Returns each member with id, memberId, firstName, lastName, email, bio, country, linkedinUrl, applicationAnswer. Use memberId (not id) for subsequent approve/reject calls.",
  "input_schema": {
    "type": "object",
    "properties": {
      "groupSlug": { "type": "string", "description": "The community slug (skool.com/{slug})" },
      "limit": { "type": "number", "description": "Max members to return", "default": 50 }
    },
    "required": ["groupSlug"]
  }
}
```

```json
{
  "name": "skool_members_approve",
  "description": "Approve a pending Skool member. Pass the member's memberId (not the request id). Idempotent: re-approving an already-approved member returns 'cannot update to same role' which is a no-op.",
  "input_schema": {
    "type": "object",
    "properties": {
      "groupSlug": { "type": "string" },
      "memberId": { "type": "string", "description": "32-char hex member ID from members:pending response" }
    },
    "required": ["groupSlug", "memberId"]
  }
}
```

```json
{
  "name": "skool_posts_create_comment",
  "description": "Create a comment on a Skool post or a nested reply to a comment. For top-level comments: rootId equals parentId equals postId. For nested replies: rootId equals postId, parentId equals commentId. Content is plain text only — no HTML or markdown rendering.",
  "input_schema": {
    "type": "object",
    "properties": {
      "groupSlug": { "type": "string" },
      "rootId": { "type": "string", "description": "Always the original post's id" },
      "parentId": { "type": "string", "description": "postId for top-level comments, or commentId for nested replies" },
      "content": { "type": "string", "description": "Plain text. Use [@Name](obj://user/{userId}) for mentions." }
    },
    "required": ["groupSlug", "rootId", "parentId", "content"]
  }
}
```

Generate similar definitions for every action you want exposed. The naming convention `skool_<namespace>_<operation>` keeps the model's tool list scannable.

In your handler, when the model calls a tool, translate to an Apify run:

```javascript
async function handleToolCall(toolName, toolInput, cookies, apifyToken) {
  // Map "skool_members_approve" → action "members:approve"
  const action = toolName.replace(/^skool_/, '').replace(/_/g, ':');
  const r = await fetch(
    `https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=${apifyToken}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        action,
        cookies,
        groupSlug: toolInput.groupSlug,
        params: { ...toolInput, groupSlug: undefined },
      }),
    },
  );
  const items = await r.json();
  return items[0]; // single-action run = single dataset item
}
```

## OpenAI / Gemini — almost identical

OpenAI's `tools` array uses `function.parameters` (same JSON Schema). Gemini's `function_declarations` use `parameters`. The shapes above translate 1:1.

## LangChain example

```python
from langchain.agents import Tool
import requests

APIFY_TOKEN = "..."
GROUP_SLUG = "your-community"
COOKIES = "..."  # from auth:login

def call_actor(action, params):
    r = requests.post(
        f"https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token={APIFY_TOKEN}",
        json={"action": action, "cookies": COOKIES, "groupSlug": GROUP_SLUG, "params": params},
    )
    return r.json()[0]

tools = [
    Tool(
        name="skool_members_pending",
        description="List members awaiting approval. Returns memberId for each.",
        func=lambda _: call_actor("members:pending", {"limit": 50}),
    ),
    Tool(
        name="skool_members_approve",
        description="Approve a member. Input: memberId (32-char hex).",
        func=lambda memberId: call_actor("members:approve", {"memberId": memberId}),
    ),
    # ...
]
```

## Claude Code Skill

If you use [Claude Code](https://docs.claude.com/en/docs/claude-code/), drop the `skool-actor` skill into `.claude/skills/skool-actor/`:

```
.claude/skills/skool-actor/
├── SKILL.md       ← invocation triggers + reference table + auth flow
└── scripts/
    ├── login.sh
    ├── post.sh
    ├── comment.sh
    └── approve.sh
```

The minimal `SKILL.md` is in [`skills/claude-code/skool-actor/`](../skills/claude-code/skool-actor/SKILL.md) of this repo. Copy that folder into your `.claude/skills/` and Claude Code will surface it whenever you say things like "list pending Skool members" or "publish a course from this markdown."

## MCP (Model Context Protocol) server pattern

If you want the actor accessible to **any** MCP-aware client (Claude Desktop, Cursor, Cline, etc.), wrap it as a self-hosted MCP server:

```javascript
// server.js — minimal MCP server proxying to Apify
import { Server } from '@modelcontextprotocol/sdk/server';

const server = new Server({ name: 'skool-actor', version: '0.1.0' }, {
  capabilities: { tools: {} },
});

server.setRequestHandler('tools/list', async () => ({
  tools: [
    {
      name: 'skool_members_pending',
      description: 'List Skool members awaiting approval',
      inputSchema: { /* JSON Schema */ },
    },
    // ... more tools
  ],
}));

server.setRequestHandler('tools/call', async (req) => {
  const action = req.params.name.replace(/^skool_/, '').replace(/_/g, ':');
  const result = await callActor(action, req.params.arguments);
  return { content: [{ type: 'text', text: JSON.stringify(result, null, 2) }] };
});

server.start();
```

Then in Claude Desktop's `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "skool": {
      "command": "node",
      "args": ["/path/to/server.js"],
      "env": {
        "APIFY_TOKEN": "...",
        "SKOOL_COOKIES": "...",
        "SKOOL_GROUP_SLUG": "..."
      }
    }
  }
}
```

The Skool community + Apify reach gets a free integration with every MCP-aware tool.

## Agent loop pattern: auto-respond to comments

Pseudo-code for an agent that monitors new comments and replies on-brand:

```javascript
// 1. Every N minutes:
const posts = await callActor('posts:list', { limit: 5 });
for (const post of posts.posts) {
  const { comments } = await callActor('posts:getComments', { postId: post.id });
  for (const c of comments) {
    if (c.author.id === selfUserId) continue;          // skip own comments
    if (await alreadyReplied(c.id)) continue;          // skip already-replied
    if (post.commentCount > THRESHOLD) continue;       // skip already-active threads

    // 2. Ask LLM to draft a reply
    const draft = await llmDraftReply({
      postContent: post.content,
      commentContent: c.content,
      brandVoice: brandVoiceMd,
    });

    // 3. Human approval (or auto-publish for low-stakes)
    if (await humanApprove(draft)) {
      await callActor('posts:createComment', {
        rootId: post.id,
        parentId: c.id,
        content: draft,
      });
    }
  }
}
```

This is the pattern running for [Cágala, Aprende, Repite](https://www.skool.com/cagala-aprende-repite) — checks daily, drafts via Claude, requires Telegram approval before publishing.

## Mistakes to avoid with agents

### ❌ Don't expose `auth:login` as a tool

`auth:login` returns secrets (cookies). If the LLM thinks it's a routine tool call, it might paste the cookies into a downstream message. Run `auth:login` once per ~3 days from a privileged side process, store cookies in a secret manager, and pass cookies to the agent's tool handler **server-side** — never as part of the tool call's input.

### ❌ Don't trust the LLM with `members:ban`

Banning is irreversible-feeling (member can't re-apply). Hold human approval before any `members:ban` — even if the LLM is "sure."

### ❌ Don't loop on `RATE_LIMIT` without backoff

If the model retries immediately after `RATE_LIMIT`, it'll just get the same error. Wrap your tool handler so it sleeps 60s before retry, then returns success/failure. Don't let the LLM see and self-retry.

### ❌ Don't expose `classroom:deleteUnit` casually

Cascading delete. Consider gating destructive actions behind a confirmation step.

## See also

- [Authentication](authentication.md) — how cookies work (relevant for agent setup)
- [Error handling](error-handling.md) — every `errorCode` has a `hint` — agents use these
- [Skill: Claude Code](../skills/claude-code/skool-actor/SKILL.md)
