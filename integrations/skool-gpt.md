---
title: "Skool + GPT — Use OpenAI's GPT to Operate a Skool Community (2026)"
description: "Connect GPT-4o, GPT-5, or any OpenAI model to Skool. Function calling schema, Assistants API, agent loops, production patterns."
slug: /integrations/skool-gpt
type: integration
primary_keyword: "skool gpt"
search_volume_monthly: 10
funnel: A
playbook: integrations
last_updated: 2026-05-19
canonical: https://github.com/ctala/skool-api-docs/blob/main/integrations/skool-gpt.md
---


> **Quick reference (TL;DR for agents)**
> - **What this enables:** Any OpenAI model (GPT-4o, GPT-5, o1, o3, o3-mini) can read and write to Skool — approve members, post content, publish courses, reply to comments.
> - **Method:** OpenAI function calling → HTTP POST to [Apify-hosted Skool actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-gpt).
> - **Cost:** OpenAI API + Apify pay-per-event (~$0.005-$0.01 per Skool action).

## OpenAI function calling schema

```python
SKOOL_FUNCTION = {
    "type": "function",
    "function": {
        "name": "skool_action",
        "description": (
            "Perform a Skool action via the Apify-hosted Skool All-in-One API actor. "
            "Returns structured success or failure. On failure, read the 'hint' field and act on it."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": [
                        "posts:list", "posts:filter", "posts:get", "posts:create", "posts:update", "posts:delete",
                        "posts:createComment", "posts:getComments", "posts:pin", "posts:unpin",
                        "members:list", "members:pending", "members:approve", "members:reject", "members:ban", "members:batchApprove",
                        "classroom:listCourses", "classroom:getTree", "classroom:createCourse", "classroom:createFolder",
                        "classroom:createPage", "classroom:setBody", "classroom:updateCourse", "classroom:deleteUnit",
                        "files:uploadImage",
                        "groups:get", "groups:setAutoDM",
                        "system:health", "auth:login"
                    ]
                },
                "params": {"type": "object", "description": "Action-specific params per https://github.com/ctala/skool-api-docs/blob/main/docs/actions.md"}
            },
            "required": ["action", "params"]
        }
    }
}
```

## Minimal agent loop (Python)

```python
from openai import OpenAI
import httpx, json, os

oai = OpenAI(api_key=os.environ["OPENAI_API_KEY"])

def call_skool(action: str, params: dict) -> dict:
    resp = httpx.post(
        f"https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token={os.environ['APIFY_TOKEN']}&build=latest&timeout=90",
        json={"action": action, "cookies": os.environ["SKOOL_COOKIES"], "groupSlug": "your-community", "params": params},
        timeout=120
    )
    data = resp.json()
    return data[0] if isinstance(data, list) and data else data

def run_agent(user_request: str):
    messages = [
        {"role": "system", "content": "You are an operator for a Skool community. Use the skool_action tool to perform reads and writes. Always check 'success' before continuing."},
        {"role": "user", "content": user_request}
    ]
    while True:
        response = oai.chat.completions.create(
            model="gpt-5",   # or gpt-4o, o3, etc.
            messages=messages,
            tools=[SKOOL_FUNCTION],
        )
        msg = response.choices[0].message
        if not msg.tool_calls:
            return msg.content
        messages.append(msg)
        for call in msg.tool_calls:
            args = json.loads(call.function.arguments)
            result = call_skool(args["action"], args["params"])
            messages.append({
                "role": "tool",
                "tool_call_id": call.id,
                "content": json.dumps(result)
            })

print(run_agent("Approve the latest 3 pending Skool members. List them by name."))
```

## OpenAI Assistants API (alternative)

For longer-running agents with state, use the Assistants API:

```python
assistant = oai.beta.assistants.create(
    name="Skool Operator",
    instructions="You operate a Skool community. Use the skool_action tool for all reads and writes.",
    model="gpt-5",
    tools=[SKOOL_FUNCTION],
)

thread = oai.beta.threads.create()

oai.beta.threads.messages.create(
    thread_id=thread.id,
    role="user",
    content="Schedule a daily summary post every morning at 9am. Post text: today's wins."
)

run = oai.beta.threads.runs.create(thread_id=thread.id, assistant_id=assistant.id)

# Poll + handle tool calls in a loop (Assistants API requires explicit polling)
while True:
    run = oai.beta.threads.runs.retrieve(thread_id=thread.id, run_id=run.id)
    if run.status == "requires_action":
        tool_outputs = []
        for tc in run.required_action.submit_tool_outputs.tool_calls:
            args = json.loads(tc.function.arguments)
            result = call_skool(args["action"], args["params"])
            tool_outputs.append({"tool_call_id": tc.id, "output": json.dumps(result)})
        oai.beta.threads.runs.submit_tool_outputs(thread_id=thread.id, run_id=run.id, tool_outputs=tool_outputs)
    elif run.status == "completed":
        break
```

## Custom GPT (no-code option)

You can publish this as a **Custom GPT** in ChatGPT for personal use or to share. Actions tab → Add Action → import OpenAPI schema for the actor's endpoint:

```yaml
openapi: 3.1.0
info:
  title: Skool API
  version: 1.0.0
servers:
  - url: https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api
paths:
  /run-sync-get-dataset-items:
    post:
      operationId: skool_action
      summary: Perform a Skool action
      parameters:
        - in: query
          name: token
          required: true
          schema: {type: string}
        - in: query
          name: build
          schema: {type: string, default: latest}
        - in: query
          name: timeout
          schema: {type: integer, default: 90}
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                action: {type: string}
                cookies: {type: string}
                groupSlug: {type: string}
                params: {type: object}
              required: [action, cookies, groupSlug, params]
      responses:
        '200':
          description: Actor result
```

Add API key auth with `APIFY_TOKEN` as a Bearer-like query param. Now your Custom GPT can operate your Skool community directly from a chat.

## Cost & rate considerations

| Component | Cost |
|---|---|
| GPT-4o call (with tools) | ~$0.0025 per simple call, ~$0.05 per complex multi-tool turn |
| GPT-5 / o3 reasoning | ~10-30× GPT-4o per turn |
| Apify actor call | ~$0.005 read, ~$0.01 write |
| Skool rate limit | ~25 writes/min (Skool enforced) |

For typical "approve 10 members per day with judgment": ~$0.15/day total ($4.50/mo).

## Production gotchas

- **GPT models don't always pass `memberId` correctly.** Add it to the tool description explicitly. Or validate server-side and re-prompt on failure.
- **GPT-5 / o1 reasoning models are slower.** Use GPT-4o for high-volume agent loops; reserve reasoning models for judgment-heavy tasks (deciding *which* applicant to approve, not *how to* approve them).
- **Function calling parallelism:** GPT-4o can return multiple tool calls in one turn. Execute them in parallel safely for reads; serialize writes to respect Skool's rate limit.
- **Token consumption:** the tool schema is ~1KB. With many actions allowed, each call sends the full schema. Strip unused actions per-task to save tokens.

## Related

- [Skool + Claude](skool-claude.md)
- [Skool + LangChain](skool-langchain.md)
- [Skool for AI agents](../for/ai-agents.md)
- [Skool MCP server](skool-mcp-server.md)

---

## Plug Skool into GPT today

[**→ Open the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-gpt)

Native function calling schema. Custom GPT compatible. Pay-per-event (~$0.005-$0.01 per call).

*No Skool community yet? [Launch one in 10 minutes](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{"@context":"https://schema.org","@type":"TechArticle","headline":"Skool + GPT (OpenAI)","datePublished":"2026-05-19","author":{"@type":"Person","name":"Cristian Tala"}}
</script>
