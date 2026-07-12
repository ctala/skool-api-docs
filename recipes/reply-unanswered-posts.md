---
render_with_liquid: false
---

# Reply to unanswered Skool posts automatically

Your community's worst experience: a member posts a question, no one answers for 24 hours, they conclude "this place is dead" and stop coming back. This recipe finds posts with 0 comments and drafts an on-brand reply via LLM, with optional human approval before publishing.

Production version of this is what keeps engagement at 40% in [Cágala, Aprende, Repite](https://www.skool.com/cagala-aprende-repite).

## What you'll build

```
[n8n schedule] ─→ posts:filter (unanswered=true, since=24h ago)
                      ↓
                  for each post:
                      ↓
                  LLM drafts reply
                  (Claude / GPT-4o)
                      ↓
                  Telegram approval
                      ↓
                  posts:createComment
                  (rootId=postId, parentId=postId)
                      ↓
                  Log to NocoDB / Sheets
```

## Prerequisites

- Apify token, Skool cookies (see [authentication](../docs/authentication.md))
- LLM API key (Anthropic Claude, OpenAI, or any other)
- Telegram bot for approval (optional but recommended)

## Step 1 — Find unanswered posts

{% raw %}
```json
{
  "action": "posts:filter",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "unanswered": true,
    "since": "{{ $now.minus({hours: 24}).toISO() }}",
    "limit": 50
  }
}
```
{% endraw %}

`since` is ISO 8601. Tune the window to your community's pace — for slower communities use 48h, for faster ones 6h.

## Step 2 — Filter by relevance

Not every unanswered post should get an auto-reply. In an n8n Function or Filter node, skip:

```javascript
const post = $json;

// Skip very recent posts (give humans a chance first)
const ageMin = (Date.now() - new Date(post.createdAt).getTime()) / 60000;
if (ageMin < 60) return false;  // wait 1h before auto-reply

// Skip posts that look like announcements (length, all-caps, etc.)
if (post.content.length < 30) return false;

// Skip if the author has already gotten replies (engaged member)
// (would need a members:list lookup — optional)

return true;
```

## Step 3 — Draft via LLM

Construct a prompt with the post content, your brand voice, and clear constraints:

```
You are a helpful, concise community moderator for {community_name}.

Brand voice: {brand_voice_summary}
Examples of good replies you wrote previously: {3 examples}

A new post has been unanswered for {hours} hours. Draft a reply that:
- Is at most 2 short paragraphs
- Asks a clarifying follow-up if the post is vague
- References specific community resources when relevant (link to a course, a recipe, a previous post)
- Does NOT promise something the community can't deliver
- Sounds human, not corporate

Post title: {post.title}
Post body: {post.content}
Author first name: {post.author.firstName}

Respond with the reply text only. Plain text. No HTML.
```

Returns a draft. Keep prompt + draft for the audit log.

## Step 4 — Human approval (recommended)

Send draft to Telegram with two reply commands:

```
📝 Draft reply for "{post.title}" by {post.author.firstName}:

{draft}

Approve: /yes_{shortId}
Edit:    /edit_{shortId}
Reject:  /no_{shortId}
```

Wait for response. Only on `/yes` proceed. Keep the draft + decision in your audit table — useful for prompt iteration.

For lower-stakes communities you can skip approval and publish directly. For the first 100 auto-replies, **always require approval** so you can catch tone drift before it becomes a brand problem.

## Step 5 — Publish the comment

Top-level comment on the post:

```json
{
  "action": "posts:createComment",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "rootId": "{{ $node['Filtered post'].json.id }}",
    "parentId": "{{ $node['Filtered post'].json.id }}",
    "content": "{{ $node['Approved draft'].json.content }}"
  }
}
```

For top-level comments, `rootId == parentId == postId` (see [posts docs](../docs/posts.md#postscreatecomment)).

## Step 6 — Log

Save to NocoDB / Sheets:

| postId | author | draft | approved | published | publishedAt |

Useful for:
- Auditing tone over time
- Iterating on the LLM prompt (look at edits humans made)
- Reverting if you publish something embarrassing

## Production gotchas

### Don't reply to your own posts

`posts:filter` returns ALL unanswered posts including yours. Filter `post.author.id !== selfUserId` early.

### Don't reply to comments — only top-level posts

`posts:filter` returns posts. To find unanswered comments inside an active post, you'd use `posts:getComments` and look for replies-to-comments with no further responses. That's a different recipe (and usually not worth automating).

### Mention the author in your reply (optional)

Add `[@FirstName Lastname](obj://user/{authorId})` at the start. The author gets a notification, which dramatically increases the chance they engage back.

```
Hey [@John Smith](obj://user/abc123...) — quick thought on this:

{draft body}
```

### Rate limit yourself

The actor's rate limiter caps you at ~25 writes/min. If you have a backlog of 50 unanswered posts, the workflow batches naturally — no special handling needed. But don't run two instances of the same workflow concurrently against the same group.

### Avoid LLM hallucinations

If the LLM draft references a specific course, member, or fact, **verify it exists** before publishing. A regex check against your courses list (`classroom:listCourses`) catches the most common case ("check out the course on X" where course X doesn't exist).

## See also

- [Posts & Comments](../docs/posts.md)
- [AI Agents integration](../docs/agents.md) — full pattern for LLM + actor loops
- [Auto-approve members with n8n](auto-approve-members-n8n.md) — companion recipe

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "HowTo",
  "name": "Reply to unanswered Skool posts automatically",
  "description": "Find Skool posts with zero comments, draft an on-brand reply with an LLM, and publish after optional human approval so no member's question sits unanswered.",
  "totalTime": "PT20M",
  "tool": [
    {"@type": "HowToTool", "name": "Apify"},
    {"@type": "HowToTool", "name": "n8n"},
    {"@type": "HowToTool", "name": "LLM API"},
    {"@type": "HowToTool", "name": "Telegram bot"},
    {"@type": "HowToTool", "name": "Skool admin cookies"}
  ],
  "step": [
    {"@type": "HowToStep", "name": "Find unanswered posts", "text": "Call posts:filter with unanswered set to true and a since window tuned to your community's pace."},
    {"@type": "HowToStep", "name": "Filter by relevance", "text": "Skip very recent posts, announcements and already-engaged authors so only posts that genuinely need a reply proceed."},
    {"@type": "HowToStep", "name": "Draft with an LLM", "text": "Prompt the LLM with the post content, your brand voice and constraints to produce a concise, human-sounding plain-text draft."},
    {"@type": "HowToStep", "name": "Approve via Telegram", "text": "Send the draft to Telegram and only publish on approval. Require approval for at least the first 100 replies to catch tone drift."},
    {"@type": "HowToStep", "name": "Publish and log", "text": "Publish the top-level comment with posts:createComment where rootId equals parentId equals postId, and log the decision for prompt iteration."}
  ]
}
</script>
