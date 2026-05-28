---
title: "Auto-approve Skool members by deterministic criteria (no LLM needed)"
description: "Approve Skool waitlist applicants automatically by email domain, LinkedIn presence, or apply-form keywords — pure rules, no LLM cost. The lightweight cousin of the AI screening recipe."
slug: /recipes/conditional-member-approval
type: recipe
funnel: A
section: Recipes
last_updated: 2026-05-28
render_with_liquid: false
---

# Auto-approve Skool members by deterministic criteria

The [LLM auto-approval recipe](auto-approve-members-n8n.md) is great when your screening criteria are fuzzy (vibe of the apply answer, signal density across multiple fields). When your criteria are **deterministic** — email domain whitelist, valid LinkedIn URL pattern, apply-form keyword match — you don't need an LLM. A pure-rules filter does the job in less time, with zero per-call cost, and is fully predictable.

This recipe is the lightweight cousin. Use it when you can articulate your approval criteria as a checklist instead of a vibe.

## Quick reference (TL;DR for agents)

| | |
|---|---|
| **Goal** | Approve waitlist applicants matching deterministic rules; pass the rest to manual review |
| **Stack** | Any HTTP client + the Apify-hosted actor |
| **Actions used** | [`members:pending`](../docs/members.md#memberspending) → rule eval → [`members:batchApprove`](../docs/members.md#membersbatchapprove) |
| **Setup time** | ~10 min (define rules + script) |
| **Ongoing cost** | `$0.01 × N` approved members per run (no LLM) |
| **Best for** | Clear-cut criteria ("LinkedIn URL present" / "email domain in whitelist") |
| **Use the LLM recipe instead when** | Criteria are fuzzy ("genuinely interested founder" / "non-spam application") |

## When deterministic beats LLM

| Use this recipe | Use the LLM recipe |
|---|---|
| You can list your approval rules on a napkin | "I know a good applicant when I see one" |
| Same criteria for 6+ months without changes | Criteria evolve, want to tune via prompt |
| Cost-sensitive (LLM calls add up at scale) | Volume low enough that cost isn't a factor |
| 100% predictable decisions matter (e.g. compliance) | Some ambiguity is acceptable |

## Prerequisites

- Apify token ([sign up free](https://console.apify.com/sign-up?fpr=cristian))
- Skool admin cookies (see [Authentication](../docs/authentication.md))
- A **written rule set** — start narrow, expand once it's running cleanly

## Example rule sets that work in production

**Rule set A: founder community with LinkedIn signal**
```
APPROVE if:
  - Answer1 contains a valid linkedin.com/in/... URL
  - Answer2 is > 10 characters (some actual content in "what are you building")
  - bio is > 5 characters

REJECT if:
  - All 3 answers are < 5 characters
  - firstName / lastName look bot-generated (repeated chars, all caps gibberish)

HOLD (manual review) for everything else
```

**Rule set B: closed B2B community with email whitelist**
```
APPROVE if:
  - email domain in {domain_whitelist.txt}  # e.g. only @company.com partners

HOLD everything else
```

**Rule set C: language-filtered community**
```
APPROVE if:
  - Answer detection (langdetect / fasttext) matches "es" or "pt"
  - Answer2 > 20 chars

HOLD non-Spanish/Portuguese applicants
```

Keep rules **narrow**. Auto-approving on a borderline rule is worse than holding for manual review — the wrong member admitted is harder to remove than the right member kept waiting an extra hour.

## Step 1 — List pending applicants

```json
{
  "action": "members:pending",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "limit": 50 }
}
```

Each applicant returns the fields you need to rule on:

| Field | Use |
|---|---|
| `memberId` | Required for `batchApprove` (NOT `id`) |
| `firstName` / `lastName` | Bot/test name detection |
| `bio` | Length signal |
| `answers[]` | The substantive rule inputs |
| `source` | Acquisition channel — sometimes a rule input |

## Step 2 — Apply your rules

```python
import re

LINKEDIN_RE = re.compile(r'linkedin\.com/in/[a-z0-9-]+', re.I)
EMAIL_WHITELIST = {"acme.com", "partner.io", "your-network.com"}

def decide(applicant):
    answers = applicant.get("answers", [])
    a1 = answers[0]["answer"] if len(answers) > 0 else ""
    a2 = answers[1]["answer"] if len(answers) > 1 else ""

    # Rule set A example
    if LINKEDIN_RE.search(a1) and len(a2) > 10 and len(applicant.get("bio", "")) > 5:
        return "approve"

    # Reject obvious bot patterns
    name = (applicant.get("firstName", "") + applicant.get("lastName", ""))
    if len(set(name)) < 3:  # like "aaaaaa"
        return "reject"

    return "hold"

approve_ids = [m["memberId"] for m in pending if decide(m) == "approve"]
reject_ids = [m["memberId"] for m in pending if decide(m) == "reject"]
```

## Step 3 — Batch approve, loop reject

Use [`members:batchApprove`](../docs/members.md#membersbatchapprove) for the approve list — one call:

```json
{
  "action": "members:batchApprove",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "memberIds": ["id1", "id2", "id3"] }
}
```

For rejections (no batch variant), loop [`members:reject`](../docs/members.md#membersreject). See the [bulk-reject recipe](bulk-reject-waitlist.md) for the pattern.

## Step 4 — Verify the queue

Re-run `members:pending`. The remaining applicants should all be your "hold" bucket — the ones you'll review manually:

```json
{ "action": "members:pending", "cookies": "...", "groupSlug": "your-community", "params": {} }
```

Notify yourself (Telegram / Slack / email) with the count: "12 applicants in hold queue — review when you can." This is the cron's only manual touchpoint.

## Pairing with the LLM recipe

Many communities run **both** in sequence:

1. **Deterministic pass first** (this recipe) — fast, free per call, clears the obvious yes/no decisions
2. **LLM pass second** — only the "hold" bucket, where rules can't decide

You get the best of both: cheap on the easy cases, smart on the borderline ones, fully transparent on which path made each decision.

## Production gotchas

- **`memberId` vs `id`.** Same trap as everywhere else in Skool's API. `members:pending` returns both; `batchApprove` and `reject` need `memberId`. Confusing them returns silent 404. ([details](../docs/members.md#common-gotchas))
- **Empty rule outputs.** If your filter is too strict and approves 0 applicants per run, the cron is still working — it's your rules. Sanity-check by manually inspecting `pending` output once a week.
- **Rule drift.** Your community evolves. A 6-month-old rule set may be approving the wrong people. Schedule a quarterly rule review.
- **Reject is irreversible from the member's side.** Be more conservative on the reject criteria than on the approve criteria. False positives in reject are more costly than false positives in hold.
- **The rule needs to be inspectable.** Log every decision (`memberId, decision, matched_rule`) to a CSV or DB so you can audit if a member complains "I applied 3 times and you rejected me."

## See also

- [Recipe: Auto-approve members with n8n + GPT-4o](auto-approve-members-n8n.md) — the LLM-based screening (fuzzy criteria)
- [Recipe: Review & batch-approve your waitlist](review-and-batch-approve-waitlist.md) — pure human-in-the-loop (you decide)
- [Recipe: Bulk-reject waitlist applicants](bulk-reject-waitlist.md) — the negative counterpart
- [Members API reference](../docs/members.md) — every member action with params and gotchas

---

## Use this in production — no setup

The hardest part of building Skool automation isn't the API logic — it's the auth (cookies expire every ~3.5 days, WAF token rotation, weekly Skool buildId changes). The **[Skool All-in-One API actor on Apify](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=conditional-member-approval&fpr=cristian)** handles all of that.

- Pay-per-event pricing (~$1.50/mo for typical communities)
- Zero LLM cost for the deterministic path — pure rules in your script + the actor's batch action
- Built by a solo community admin who didn't want LLM cost on every applicant just to filter the easy ones

[**→ Open the actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=conditional-member-approval&fpr=cristian)

*New to Skool? [Launch your community here](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*
