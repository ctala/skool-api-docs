---
title: "Skool + Claude — Use Anthropic's Claude to Operate a Skool Community (2026)"
description: "Connect Claude (Anthropic API, Claude Desktop, Claude Code) to Skool. Tool-use schema, MCP integration, agent loops, real production patterns."
slug: /integrations/skool-claude
type: integration
primary_keyword: "skool claude"
search_volume_monthly: 10
funnel: A
playbook: integrations
last_updated: 2026-05-19
canonical: https://github.com/ctala/skool-api-docs/blob/main/integrations/skool-claude.md
---


> **Quick reference (TL;DR for agents)**
> - **What this enables:** Claude (via Anthropic API, Claude Desktop with MCP, or Claude Code Skills) operates your Skool community — approve members, post updates, reply to comments, publish courses.
> - **Three integration paths:** (1) Claude tool-use API, (2) Claude Desktop + MCP server, (3) Claude Code Skill (drop-in).
> - **Cost:** Anthropic API calls + Apify pay-per-event (~$0.005-$0.01 per Skool action).

## Why Claude specifically?

The [Apify-hosted Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-claude) is **AI-agent-native**: never-throw contract, structured `hint` field for recovery, idempotency where it matters. Claude in particular benefits from this because:

1. Claude's tool-use API can return any tool result back to the model — Claude reads `hint` and self-corrects.
2. Claude Desktop ships native MCP support — connect once, Claude sees every Skool action as a tool.
3. Claude is good at **judgment calls** that Skool automation needs: which applicants to approve, what tone to use in a comment reply, what category a post fits.

Per Apify analytics, claude.ai is already the 5th-largest referrer to the actor — Claude users are discovering it organically.

## Path 1 — Claude tool-use API (Python)

```python
from anthropic import Anthropic
import httpx, json, os

anthropic = Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

SKOOL_TOOL = {
    "name": "skool_action",
    "description": (
        "Perform a Skool action via the Apify-hosted Skool All-in-One API actor. "
        "Returns {success: true, data: ...} or {success: false, errorCode, hint}."
    ),
    "input_schema": {
        "type": "object",
        "properties": {
            "action": {
                "type": "string",
                "enum": [
                    "posts:list", "posts:create", "posts:createComment",
                    "members:pending", "members:approve", "members:reject", "members:batchApprove",
                    "classroom:listCourses", "classroom:getTree", "classroom:createPage", "classroom:setBody",
                    "groups:get", "groups:setAutoDM",
                    "files:uploadImage", "system:health"
                ]
            },
            "params": {"type": "object"}
        },
        "required": ["action", "params"]
    }
}

def call_skool_actor(action: str, params: dict) -> dict:
    resp = httpx.post(
        f"https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token={os.environ['APIFY_TOKEN']}&build=latest&timeout=90",
        json={"action": action, "cookies": os.environ["SKOOL_COOKIES"], "groupSlug": "your-community", "params": params},
        timeout=120
    )
    data = resp.json()
    return data[0] if isinstance(data, list) and data else data

def run_agent(user_request: str):
    messages = [{"role": "user", "content": user_request}]
    while True:
        response = anthropic.messages.create(
            model="claude-opus-4-7",   # latest as of 2026
            max_tokens=4096,
            tools=[SKOOL_TOOL],
            messages=messages,
        )
        if response.stop_reason == "end_turn":
            return response.content[0].text
        if response.stop_reason == "tool_use":
            messages.append({"role": "assistant", "content": response.content})
            tool_results = []
            for block in response.content:
                if block.type == "tool_use":
                    result = call_skool_actor(block.input["action"], block.input["params"])
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": json.dumps(result),
                    })
            messages.append({"role": "user", "content": tool_results})

print(run_agent("Approve the latest 5 pending Skool members. Show me a one-line summary of each."))
```

Claude reads pending applicants, decides which to approve, calls the tool for each, summarizes. With prompt caching, the system prompt + tool schema cache and each subsequent call is fast.

## Path 2 — Claude Desktop + MCP server

Claude Desktop natively supports MCP. Drop the Skool MCP server into your config and Claude sees every actor action as a tool.

See **[Skool MCP Server — Production Setup](skool-mcp-server.md)** for full server code (Python, ~150 lines) and the Claude Desktop config snippet.

Quick version of the config (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "skool": {
      "command": "npx",
      "args": [
        "-y", "@apify/actors-mcp-server",
        "--token=YOUR_APIFY_TOKEN",
        "--actor=cristiantala/skool-all-in-one-api"
      ]
    }
  }
}
```

Restart Claude. Skool actions appear in the tools panel. Ask Claude to operate your community in natural language.

## Path 3 — Claude Code Skill (drop-in)

If you're a Claude Code user, install the bundled Skill:

```bash
mkdir -p ~/.claude/skills/skool-actor
curl -L https://raw.githubusercontent.com/ctala/skool-api-docs/main/skills/claude-code/skool-actor/SKILL.md \
  -o ~/.claude/skills/skool-actor/SKILL.md

mkdir -p ~/.claude/skills/skool-actor/scripts
for s in login.sh post.sh comment.sh approve.sh; do
  curl -L https://raw.githubusercontent.com/ctala/skool-api-docs/main/skills/claude-code/skool-actor/scripts/$s \
    -o ~/.claude/skills/skool-actor/scripts/$s
  chmod +x ~/.claude/skills/skool-actor/scripts/$s
done
```

Set env vars in `~/.zshrc`:

```bash
export APIFY_TOKEN=apify_api_...
export SKOOL_EMAIL=admin@example.com
export SKOOL_PASSWORD=...
export SKOOL_GROUP_SLUG=your-community-slug
export SKOOL_COOKIES=                  # populated after first auth:login
```

Restart Claude Code. Now in any conversation:

> "List my pending Skool members and approve the ones with verified LinkedIn."

Claude Code reads the Skill, runs the right actor actions in sequence, and reports back.

## Real production agent loop

Pattern used on a 484-member production community:

```
1. Cron triggers Claude → "review pending applicants and act"
2. Claude calls members:pending
3. For each pending member, Claude reads metadata (LinkedIn, survey answers)
4. Claude classifies: clear approve, clear reject, needs human review
5. Claude calls members:batchApprove for the clear approves
6. Claude posts a summary in Telegram for human review of borderline cases
7. Human responds in Telegram → Claude calls approve/reject as instructed
```

End-to-end: ~$0.50/run, runs once daily, replaces 30 minutes of manual screening per day.

## Error recovery — Claude reads the `hint`

When the actor returns `{success: false, errorCode: "WAF_EXPIRED", hint: "Re-run auth:login with email/password and store new cookies"}`, Claude reads the hint and takes the right next step without any custom error-handling logic:

> **Tool result:** {success: false, errorCode: "WAF_EXPIRED", hint: "Re-run auth:login..."}
>
> **Claude:** Cookies expired. Running auth:login now.
>
> [tool: skool_action {action: "auth:login", params: {email: ..., password: ..., groupSlug: ...}}]

This is why the actor's error schema is designed to be LLM-readable rather than human-machine-readable.

## Common patterns

| Pattern | Implementation |
|---|---|
| **Approval queue review** | Claude reads `members:pending` → classifies → `members:batchApprove` |
| **Daily community digest** | Claude reads `posts:list` (last 24h) → summarizes → DMs you via Telegram |
| **Tone-correct comment replies** | Claude reads unanswered posts → drafts in your voice → human approves → publishes |
| **Course publishing from notes** | Claude reads markdown → `classroom:createCourse` + `classroom:setBody` per page |
| **Auto DM A/B testing** | Claude rotates `groups:setAutoDM` between variants weekly, you measure conversion |

## Production gotchas

- **Cache the system prompt + tool schema.** Anthropic supports prompt caching; the Skool tool schema is ~2KB and rarely changes. Save 90%+ of input tokens.
- **Constrain Claude to a sub-action list per task.** For "approve members" tasks, only expose `members:*` actions. Less for Claude to consider = better focus + faster.
- **`memberId` vs `id`** — even Claude trips on this. Add it explicitly to the tool description: "use memberId from members:pending, NOT user id".
- **Human-in-the-loop for first 100 operations.** Trust Claude's judgment after you've validated tone + reasoning patterns against your community.

## Related

- [Skool for AI agents](../for/ai-agents.md) — full pattern + function-calling specs
- [Skool + GPT (OpenAI)](skool-gpt.md)
- [Skool + LangChain](skool-langchain.md)
- [Skool MCP server](skool-mcp-server.md)

---

## Plug Skool into Claude today

[**→ Open the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-claude)

Three integration paths: Claude tool-use API, Claude Desktop + MCP, Claude Code Skill. Pay-per-event (~$0.005-$0.01 per call).

*No Skool community yet? [Launch one in 10 minutes](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{"@context":"https://schema.org","@type":"TechArticle","headline":"Skool + Claude","datePublished":"2026-05-19","author":{"@type":"Person","name":"Cristian Tala"}}
</script>
