---
title: "Export Skool members to CSV (email, tier, LTV, survey answers)"
description: "Export your full Skool member list as CSV via the API — same data as the admin Export button, but automatable: email, joined date, tier, LTV, application answers."
slug: /recipes/export-skool-members-csv
type: recipe
funnel: A
section: Recipes
last_updated: 2026-05-28
render_with_liquid: false
---

# Export Skool members to CSV

The Skool admin panel has an "Export" button that downloads your member roster as CSV — but only if you click it manually. This recipe does the same thing **via the API**, so you can pipe it into a CRM, an analytics pipeline, or a nightly snapshot job.

The exported CSV is the **only reliable source for member emails on Skool**. The server-rendered member list returns `email:""` (Skool strips it from the SSR payload), and `GET /users/{id}` only returns the email of the *authenticated* user — even community owners see masked emails for third parties. The bulk export is the workaround Skool itself uses for the admin UI button.

It's the exact flow that backs [Cágala, Aprende, Repite](https://www.skool.com/cagala-aprende-repite)'s [CRM single-source-of-truth pipeline](../automation/export-skool-members.md).

## Quick reference (TL;DR for agents)

| | |
|---|---|
| **Goal** | Export your Skool member roster (active / cancelling / churned / banned) as CSV |
| **Stack** | Any HTTP client (curl / Python / n8n) + the Apify-hosted actor |
| **Actions used** | [`members:export`](../docs/members.md#membersexport--bulk-csv-export) |
| **Setup time** | ~3 min |
| **Ongoing cost** | `$0.05` per export run (regardless of community size) |
| **Output** | CSV: `FirstName, LastName, Email, Invited By, JoinedDate, Question1-3, Answer1-3, Price, Recurring Interval, Tier, LTV` |
| **Key gotcha** | Async 3-step flow under the hood. The actor wraps it — you get the CSV string back in one call |

## Prerequisites

- Apify token ([get one](https://console.apify.com/account/integrations?fpr=cristian))
- Skool admin/owner cookies for the community you're exporting (see [Authentication](../docs/authentication.md))
- You're an **admin or owner** — export is an admin-only action

## What the export returns

Real shape from a production community (728 members, 28-may-2026):

```csv
FirstName,LastName,Email,Invited By,JoinedDate,Question1,Question2,Question3,Answer1,Answer2,Answer3,Price,Recurring Interval,Tier,LTV
Maria,Lopez,maria@example.com,,2026-04-12,What's your LinkedIn?,What are you building?,How did you find us?,linkedin.com/in/marialopez,SaaS for restaurants,Newsletter,0,,standard,0
...
```

Data quality reality check (measured on a 728-member community):

- **~68% of members have a populated Email column.** The other ~32% (typically members who joined via the Skool Discovery network) don't share their email with the community owner — Skool keeps that field empty in the export.
- **~88% have a LinkedIn URL in `Answer1`** — when the apply form asks for it. Apply-form answers are far more complete than the email column.
- The `Invited By` column is empty unless the member came through a [referral link](../learn/skool-affiliate-program.md).

If you need the **acquisition source** (`Joined from {channel}`), that's NOT in the CSV — it's in `member.metadata.attrSrcComp` from the SSR payload. Use [`members:list`](../docs/members.md#memberslist) for that.

## Step 1 — Call the export action

```json
{
  "action": "members:export",
  "cookies": "auth_token=...; client_id=...; aws-waf-token=...",
  "groupSlug": "your-community",
  "params": {
    "status": "active",
    "tiers": ["standard", "premium", "vip"]
  }
}
```

| Param | Values | Default |
|---|---|---|
| `status` | `active` / `cancelling` / `churned` / `banned` | `active` |
| `tiers` | array of tier slugs you defined in admin (e.g. `["standard", "premium", "vip"]`) | all tiers |
| `sortType` | empty string (sort is Skool-default) | `""` |

Behind the scenes the actor runs the 3-step async flow that Skool's admin UI runs when you click Export:

1. `POST /groups/{id}/request-bulk-action?type=bulk-export-csv` → returns `{token, file_id}`
2. `GET /wait?token={token}` → polls `in-progress` → `completed` (typically 2-8 sec)
3. `POST /files/{file_id}/download-url` → returns a signed CloudFront URL (expires in ~5 min) → GET that URL = CSV body

You don't see any of that — the actor returns the CSV string directly in the dataset.

## Step 2 — Get the CSV

The synchronous run-sync-get-dataset-items endpoint gives you the CSV in one HTTP call:

```bash
curl -X POST \
  "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=$APIFY_TOKEN&timeout=60&build=latest" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "members:export",
    "cookies": "'"$SKOOL_COOKIES"'",
    "groupSlug": "your-community",
    "params": { "status": "active" }
  }'
```

Response is a JSON array with one item, where `csv` contains the full CSV body:

```json
[
  {
    "success": true,
    "csv": "FirstName,LastName,Email,...\nMaria,Lopez,maria@example.com,...\n...",
    "rowCount": 728
  }
]
```

Pipe it straight to a file:

```bash
curl ... | jq -r '.[0].csv' > members-$(date +%F).csv
```

## Step 3 — Pipe into your CRM / analytics

The two patterns we use in production:

**A. Nightly snapshot → NocoDB.** A cron job fetches the export, diffs against yesterday's, and upserts into `crm.personas` keyed by `Email`. New rows get a `joined_at` timestamp, missing rows get `churned_at`. This is the [CRM single-source-of-truth flow](../automation/export-skool-members.md).

**B. On-demand pull for a specific cohort.** Export `tier=premium`, filter by `JoinedDate >= 30 days ago`, send each row to a personalized email sequence in Listmonk / Postmark. The `Answer1-3` columns give you the personalization data (their LinkedIn, what they're building, where they heard about you).

## Production gotchas

- **`build.stale` error = expired cookies, not a bug.** Skool's `aws-waf-token` rotates ~every 3.5 days. When yours expires, the actor returns `BuildIdStaleError` (or `build.stale`). Fix: re-run your cookie refresh script (we use `auth_login.py`). Document this as your first debugging step.
- **Email gap is structural, not a bug.** ~32% of members will have empty `Email` columns. Don't assume the export failed — Skool simply doesn't share the email when the member joined via the Discovery network. For those members, fall back to LinkedIn from `Answer1`.
- **CSV is generated on-demand by Skool — small communities get it in 2 sec, communities with 10K+ members can take 30+ sec.** Set your HTTP client timeout to at least 90 sec.
- **Don't export every 5 minutes.** The export is meant for daily/weekly snapshots. Calling it on every webhook is wasteful — the data doesn't change that fast, and Skool will eventually rate-limit.
- **`Invited By` is empty unless you have an active [referral program](../learn/skool-affiliate-program.md).** If you see all blanks, that's because no member came through a tracked referral — not because the export is broken.

## Pairing with `members:list` for the full picture

The CSV doesn't include the acquisition source (`Joined from LinkedIn`, `Joined from your blog`). To enrich your CRM with that, also run `members:list` and merge by `memberId`:

```json
{ "action": "members:list", "cookies": "...", "groupSlug": "your-community", "params": { "all": true } }
```

`members:list` returns `joinedFrom` / `joinedVia` per member — the missing piece for attribution analytics.

## See also

- [Members API reference](../docs/members.md) — every member action with params and gotchas
- [Automation: Export Skool members for CRM](../automation/export-skool-members.md) — the production pipeline using this action
- [Recipe: Community analytics → NocoDB](community-analytics-to-nocodb.md) — pair the export with usage data
- [Authentication](../docs/authentication.md) — how to get the cookies the export needs

---

## Use this in production — no setup

The hardest part of building Skool automation isn't the API logic — it's the auth (cookies expire every ~3.5 days, WAF token rotation, weekly Skool buildId changes). The **[Skool All-in-One API actor on Apify](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=export-skool-members-csv&fpr=cristian)** handles all of that.

- Pay-per-event pricing (~$1.50/mo for typical communities)
- One JSON POST per action — works from any HTTP client
- The 3-step async export flow is wrapped in a single call — no polling logic on your side

[**→ Open the actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=export-skool-members-csv&fpr=cristian)

*New to Skool? [Launch your community here](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "HowTo",
  "name": "Export Skool members to CSV",
  "description": "Export your full Skool member list (email, tier, LTV, survey answers) as CSV via the Skool All-in-One API actor on Apify.",
  "totalTime": "PT3M",
  "tool": [
    {"@type": "HowToTool", "name": "Apify"},
    {"@type": "HowToTool", "name": "Skool admin cookies"}
  ],
  "step": [
    {"@type": "HowToStep", "name": "Call members:export", "text": "POST to the actor with action=members:export, your community slug, and status filter (active/cancelling/churned/banned)."},
    {"@type": "HowToStep", "name": "Receive the CSV", "text": "The actor wraps Skool's 3-step async export flow and returns the CSV body directly in the dataset response."},
    {"@type": "HowToStep", "name": "Pipe into CRM or analytics", "text": "Use the CSV for nightly snapshots into NocoDB, on-demand cohort exports, or pair with members:list for acquisition-source enrichment."}
  ]
}
</script>
