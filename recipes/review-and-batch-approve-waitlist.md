---
title: "Review and batch-approve your Skool waitlist (human-in-the-loop)"
description: "Approve pending Skool members in bulk via the API: list the waitlist, screen each applicant against your criteria, then batch-approve the good ones in one call. The human-reviewed alternative to fully automated AI approval."
slug: /recipes/review-and-batch-approve-waitlist
type: recipe
funnel: A
section: Recipes
last_updated: 2026-05-21
render_with_liquid: false
---

# Review and batch-approve your Skool waitlist

When applicants pile up in your Skool approval queue, you have two options: let an AI auto-approve everyone (see [Auto-approve members with n8n + GPT-4o](auto-approve-members-n8n.md)), or **review them yourself and approve the good ones in bulk**. This recipe is the second pattern — a human-in-the-loop flow where *you* keep the judgment call but the API removes the click-fatigue of approving one by one in the Skool UI.

It's the exact flow used to clear the waitlist of [Cágala, Aprende, Repite](https://www.skool.com/cagala-aprende-repite): list pending → screen against criteria → `members:batchApprove` → verify the queue is empty.

## Quick reference (TL;DR for agents)

| | |
|---|---|
| **Goal** | Clear a Skool approval queue with human judgment, in bulk |
| **Stack** | Any HTTP client (curl / Python / Node) + the Apify-hosted actor |
| **Actions used** | [`members:pending`](../docs/members.md#memberspending--pending-applicants) → [`members:batchApprove`](../docs/members.md#membersbatchapprove--approve-n-members-in-one-run) → `members:pending` (verify) |
| **Setup time** | ~5 min |
| **Ongoing cost** | `$0.01 × N` approved members per run |
| **Key gotcha** | Use `memberId`, NOT `id`, in approve calls |
| **Helper script** | [`batch-approve.sh`](https://github.com/ctala/skool-api-docs/blob/main/skills/claude-code/skool-actor/scripts/batch-approve.sh) |

## Prerequisites

- Apify token + Skool admin cookies (see [Authentication](../docs/authentication.md)).
- You're an **admin/owner** of the community (approval is an admin write).
- A clear idea of *who you let in*. Define it before you start — see criteria below.

## Step 1 — List the waitlist

```json
{
  "action": "members:pending",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "limit": 50 }
}
```

Each applicant returns the apply-form answers plus identity fields. The two that matter for write calls:

| Field | Use |
|---|---|
| `id` | request id — for routing in your queue, **NOT** for approve |
| `memberId` | canonical user id — **this** is what `members:approve` / `members:batchApprove` need |
| `answers[]` | apply-form responses (LinkedIn, your screening question, email) |
| `source` | acquisition channel (`direct`, `external_link`, ...) |
| `bio`, `requestLocation` | extra context |

## Step 2 — Screen each applicant

The API can't make your judgment call — it just removes the clicks. Decide who passes with a simple, written rubric. A battle-tested one for a founder/creator community:

| Decision | When |
|---|---|
| ✅ **Approve** | Valid, reachable LinkedIn URL **+** a specific answer to your screening question. Fast yes. |
| ✅ **Approve (judgment)** | No LinkedIn but the answer names a concrete project / pain / journey, and the acquisition channel is qualified (your blog, newsletter, etc.). |
| ⚠️ **Hold** | No LinkedIn **+** vague one-word answer, but no obvious red flag. Decide case by case. |
| ❌ **Reject** | Bot/test name, all-vague answers, or invalid LinkedIn **+** one-word bio **+** one-word answer. |

> **LinkedIn is self-reported.** The actor returns whatever the applicant pasted — Skool doesn't verify it. If you approve based on LinkedIn presence, spot-check that the URL resolves and matches the name.

Collect the `memberId` of everyone who passed into a list.

## Step 3 — Batch-approve the winners

One call approves all of them. Failures don't block the batch — you get a per-item result array.

```json
{
  "action": "members:batchApprove",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "memberIds": [
      "da736b72398f4dc19f24fcf255dd562c",
      "8a589dd5bb824c76b4a3738330be0335",
      "164956a8b185476789307fc4740db7cd"
    ]
  }
}
```

Response:

```json
[
  { "memberId": "da736b72398f4dc19f24fcf255dd562c", "success": true },
  { "memberId": "8a589dd5bb824c76b4a3738330be0335", "success": true },
  { "memberId": "164956a8b185476789307fc4740db7cd", "success": true }
]
```

Or with the helper script (reads `.env`, takes ids as args or on stdin):

```bash
# explicit ids
./batch-approve.sh da736b72... 8a589dd5... 164956a8...

# or pipe straight from the pending list
curl -s ... members:pending | jq -r '.[].memberId' | ./batch-approve.sh
```

## Step 4 — Verify the queue (don't trust the 200)

Re-run `members:pending` and confirm only the ones you intentionally held remain:

```json
{ "action": "members:pending", "cookies": "...", "groupSlug": "your-community", "params": {} }
```

A clean run returns `[]` (or just your held applicants). Skool's write actions can return success while a downstream effect silently no-ops, so this read-back is the real confirmation.

## Production gotchas

- **`memberId` vs `id`.** The single most common mistake. `members:pending` returns both; approve/reject need `memberId`. Passing `id` gives a silent **404 (member not found)** — the whole batch fails without an obvious reason. ([details](../docs/members.md#common-gotchas))
- **Already-approved members.** If someone got approved between your list and your batch, that item returns `cannot update to same role` — a harmless no-op, not a real error. The script treats it as success.
- **Rate limit.** The actor serializes the batch internally (~25 writes/min, Skool's ceiling). Don't add your own retry loop on top — you'll just trip the limit.
- **Empty list.** `members:batchApprove` with `memberIds: []` is a no-op; guard against it so you don't fire an empty run.

## Manual review vs full automation — which to use

| | This recipe (human-in-the-loop) | [Auto-approve with AI](auto-approve-members-n8n.md) |
|---|---|---|
| Who decides | You, in bulk | LLM screens, auto-approves the pass list |
| Best for | Lower volume, or communities where the wrong member is costly | High volume (10+/day), criteria that an LLM can reliably apply |
| Trade-off | Costs your minutes, keeps your taste | Hands-off, but tune the prompt or you over/under-admit |

Many communities run both: AI auto-approves the obvious yeses, and a periodic human batch-review clears the queued "maybe" pile — this recipe is that second step.

## See also

- [Members reference](../docs/members.md) — every member action with params and gotchas
- [Recipe: Auto-approve members with n8n + GPT-4o](auto-approve-members-n8n.md) — the fully automated counterpart
- [Recipe: Auto DM new members](auto-dm-new-members.md) — pair approval with a welcome DM for end-to-end onboarding
- [AI agents integration guide](../docs/agents.md) — wiring these actions into an autonomous agent

---

[**→ Open the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=batch-approve&fpr=cristian) — pay-per-event (~$1.50/mo typical).

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "HowTo",
  "name": "Review and batch-approve your Skool waitlist",
  "description": "Approve pending Skool members in bulk via the API: list the waitlist, screen each applicant against your criteria, then batch-approve the good ones in one call.",
  "totalTime": "PT5M",
  "tool": [
    {"@type": "HowToTool", "name": "Apify"},
    {"@type": "HowToTool", "name": "Skool admin cookies"}
  ],
  "step": [
    {"@type": "HowToStep", "name": "List the waitlist", "text": "Call members:pending to pull applicants with their apply-form answers and both id and memberId."},
    {"@type": "HowToStep", "name": "Screen each applicant", "text": "Apply a written rubric (reachable LinkedIn plus a specific answer to approve, bot names or all-vague answers to reject) and collect the memberId of everyone who passes."},
    {"@type": "HowToStep", "name": "Batch-approve the winners", "text": "Pass the collected memberIds to members:batchApprove in one call. Failures return per-item results without blocking the batch."},
    {"@type": "HowToStep", "name": "Verify the queue", "text": "Re-run members:pending to confirm only intentionally held applicants remain. The read-back is the real confirmation, not the 200."}
  ]
}
</script>
