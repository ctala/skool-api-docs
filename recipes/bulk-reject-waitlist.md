---
title: "Bulk-reject Skool waitlist applicants (the missing complement to batch-approve)"
description: "Reject low-signal Skool membership applications in bulk via the API — list pending, screen out the obvious nos, mark them rejected in one call. Pairs with batch-approve."
slug: /recipes/bulk-reject-waitlist
type: recipe
funnel: A
section: Recipes
last_updated: 2026-05-28
render_with_liquid: false
---

# Bulk-reject Skool waitlist applicants

[Batch-approving](review-and-batch-approve-waitlist.md) the good applicants is half the workflow. The other half is **rejecting the obvious nos** — applications with bot/test names, all-vague answers, invalid LinkedIn URLs, or no signal at all. Doing that one-by-one in the Skool admin is tedious and slow. The API lets you reject in bulk.

This recipe is the **negative counterpart** to batch-approve: same list → opposite decision → `members:reject` instead of `members:batchApprove`. Use them together to clear a queue end-to-end in minutes.

## Quick reference (TL;DR for agents)

| | |
|---|---|
| **Goal** | Reject low-signal Skool waitlist applications in bulk |
| **Stack** | Any HTTP client + the Apify-hosted actor |
| **Actions used** | [`members:pending`](../docs/members.md#memberspending) → [`members:reject`](../docs/members.md#membersreject) (one call per rejection) |
| **Setup time** | ~5 min |
| **Ongoing cost** | `$0.01 × N` rejections |
| **Key gotcha** | `memberId`, NOT `id`. Same trap as approve — silent 404 otherwise |
| **Pairs with** | [Review & batch-approve waitlist](review-and-batch-approve-waitlist.md) |

## Prerequisites

- Apify token ([sign up free](https://console.apify.com/sign-up?fpr=cristian))
- Skool admin cookies (see [Authentication](../docs/authentication.md))
- A **written rubric** of who you reject (avoid case-by-case decisions in a bulk pass)

## A reject rubric that won't bite you back

Rejection is irreversible from the member's side (they don't get an email, but if they re-apply you'll see them in the queue again with the same data). Have a clear filter so you don't reject someone you wish you'd held:

| Reject | Signal |
|---|---|
| **Bot or test name** | "asdf", "test test", repeated chars in firstName/lastName |
| **All-vague answers** | "ok" / "yes" / "interested" across all 3 application questions |
| **Invalid LinkedIn + one-word bio + one-word answer** | No reachable identity, no signal of intent |
| **Disposable email domain** (if Email is populated) | `mailinator.com`, `tempmail.com`, etc — usually paired with bot signals |

Anything ambiguous → **hold**, not reject. Holds are cheap; the wrong reject is not.

## Step 1 — List the waitlist

Same as for batch-approve:

```json
{
  "action": "members:pending",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "limit": 50 }
}
```

The fields you need for rejection: `memberId` (canonical user id for write calls), `firstName`/`lastName`/`bio`/`answers[]` (for the rubric), `source` (the acquisition channel — sometimes a tell).

## Step 2 — Reject each (one call per rejection)

`members:reject` is one-at-a-time (unlike batch-approve which has a `batchApprove` variant). Loop the rejections:

```json
{
  "action": "members:reject",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "memberId": "abc123...32hex"
  }
}
```

Response:

```json
{
  "success": true,
  "memberId": "abc123..."
}
```

## Step 3 — Verify the queue

Re-run `members:pending` and confirm only the held applicants remain:

```json
{ "action": "members:pending", "cookies": "...", "groupSlug": "your-community", "params": {} }
```

A clean run returns `[]` (or just your held ones). Like approve, **never trust the 200** — read-back is the only proof.

## The combined sweep pattern

In practice you run **all three in sequence** to clear a queue end-to-end:

```
1. members:pending → split into 3 buckets (approve / reject / hold)
2. members:batchApprove(approveList)  — one call
3. members:reject(rejectId) × N        — loop
4. members:pending → verify only holds remain
```

The whole sequence for a queue of ~30 applicants runs in under a minute via the API. The same flow in the Skool admin UI is ~15 minutes of clicking.

## Production gotchas

- **`memberId` vs `id` (the canonical Skool API trap).** `members:pending` returns both — `id` is the request id, `memberId` is the user id. Reject (and approve) need `memberId`. Pass `id` → silent `HTTP 404: member not found`. ([details](../docs/members.md#common-gotchas))
- **No `batchReject`.** Unlike approve, there's no batch variant — you loop the reject calls. The actor handles internal serialization to avoid Skool's rate limit (~25 writes/min).
- **Rejection is final from the member's POV.** They aren't notified, but the slot is gone. If they re-apply, you'll see them again — same data, same `id` but possibly different `memberId` (Skool re-assigns on re-application).
- **Empty reject list is a no-op.** Guard against firing the action with no `memberId` — it returns an error.
- **Don't reject + approve the same person in one batch.** Order matters internally. If you split the list correctly in step 1, this shouldn't happen — but if it does, the actor will surface the conflict.

## See also

- [Review & batch-approve your waitlist](review-and-batch-approve-waitlist.md) — the positive counterpart
- [Auto-approve members with n8n + GPT-4o](auto-approve-members-n8n.md) — fully automated alternative (no human bulk-reject step needed)
- [Members API reference](../docs/members.md) — every member action with params and gotchas

---

## Use this in production — no setup

The hardest part of building Skool automation isn't the API logic — it's the auth (cookies expire every ~3.5 days, WAF token rotation, weekly Skool buildId changes). The **[Skool All-in-One API actor on Apify](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=bulk-reject-waitlist&fpr=cristian)** handles all of that.

- Pay-per-event pricing (~$1.50/mo for typical communities)
- One JSON POST per action — works from any HTTP client
- `memberId` vs `id` trap is wrapped — the action validates the right field

[**→ Open the actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=bulk-reject-waitlist&fpr=cristian)

*New to Skool? [Launch your community here](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "HowTo",
  "name": "Bulk-reject Skool waitlist applicants",
  "description": "Reject low-signal Skool membership applications in bulk via the members:reject action. Pairs with batch-approve for end-to-end queue clearance.",
  "totalTime": "PT5M",
  "tool": [{"@type": "HowToTool", "name": "Apify"}, {"@type": "HowToTool", "name": "Skool admin cookies"}],
  "step": [
    {"@type": "HowToStep", "name": "List pending", "text": "Call members:pending to get the queue with memberId and applicant data."},
    {"@type": "HowToStep", "name": "Filter against your rubric", "text": "Split into approve / reject / hold buckets based on a written rejection rubric (bot names, all-vague answers, invalid LinkedIn + no signal)."},
    {"@type": "HowToStep", "name": "Loop members:reject", "text": "One call per rejection with memberId. Verify queue with a final members:pending read-back."}
  ]
}
</script>
