---
title: "Skool community analytics: export data to NocoDB or Airtable"
description: "Build your own Skool BI dashboard — scheduled actor runs export members and engagement to NocoDB, Airtable or Postgres for churn tracking."
slug: /recipes/community-analytics-to-nocodb
type: recipe
funnel: A
section: Recipes
last_updated: 2026-07-12
render_with_liquid: false
---

# Community analytics: export Skool data to NocoDB / Airtable

**Use case**: Skool's built-in analytics are minimal. You want your own BI dashboard tracking members over time, engagement by category, churn signals, and free → paid conversion. This recipe shows the pattern: scheduled actor runs that export Skool data to your own database (NocoDB, Airtable, Postgres, or anywhere) for analysis.

The stack we use in production: Skool actor → n8n cron → NocoDB tables → Metabase / Grafana for dashboards. But the pattern works with any tools.

## What you'll track

| Table | What it captures | Update frequency |
|---|---|---|
| `members_snapshots` | Full member list each week with role, level, joined_at, last_active_at | Weekly |
| `posts_engagement` | Each post with author, category, comments, likes, created_at | Daily incremental |
| `member_activity` | Per-member metric: posts_count, comments_count, last_post_at | Daily |
| `cohorts` | New members grouped by join week, tracked for activation + retention | Weekly |
| `revenue_signals` | Members who upgraded tier, when, and what they posted before upgrading | On-demand |

## The recipe

### Step 1 — Schema in NocoDB (or your DB of choice)

Create a NocoDB base with these tables:

```
members_snapshots
├── id (autonumber, PK)
├── snapshot_date (date)
├── skool_user_id (text)
├── first_name (text)
├── last_name (text)
├── username (text)
├── joined_at (datetime)
├── role (text) — member / admin / banned
├── tier (number) — 0 free, 2 premium, 3 vip
├── level (number)
├── linkedin_url (text)
└── why_join (text)

posts_engagement
├── id (autonumber, PK)
├── post_id (text, unique)
├── author_id (text)
├── author_name (text)
├── category_id (text)
├── title (text)
├── content_preview (text — first 500 chars)
├── comment_count (number)
├── like_count (number)
├── pinned (bool)
├── created_at (datetime)
└── last_synced (datetime)

member_activity
├── id (autonumber, PK)
├── skool_user_id (text)
├── period_start (date) — Monday of the week
├── posts_count (number)
├── comments_count (number)
├── likes_received (number)
└── last_post_at (datetime)
```

### Step 2 — n8n workflow: weekly member snapshot

**Trigger**: Cron every Monday at 9am.

**Nodes**:

1. **HTTP Request** — `auth:login` if cookies expired, otherwise skip
2. **HTTP Request** — `members:list` (paginated, iterate until empty)
3. **Code node** — flatten members array, add `snapshot_date = today`
4. **NocoDB Insert Bulk** — upsert into `members_snapshots`
5. **Code node** — compute deltas vs last snapshot:
   - New joiners: in this snapshot, not in last
   - Churners: in last snapshot, not in this
   - Upgrades: tier increased
   - Downgrades: tier decreased
6. **Telegram notification** — summary delta to your ops channel

Example actor call:

```bash
curl -X POST "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=$APIFY_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "action": "members:list",
    "groupSlug": "my-community",
    "cookies": "auth_token=...; ...",
    "params": {
      "page": 1
    }
  }'
```

### Step 3 — n8n workflow: daily post engagement sync

**Trigger**: Cron every day at 3am (low-traffic window).

**Nodes**:

1. **HTTP Request** — `posts:list` (pages 1-3, covers last ~96 posts which is typically all activity in 24h)
2. **Code node** — for each post, compute `last_synced = now`
3. **NocoDB Upsert by post_id** — insert new posts, update existing ones with new comment_count/like_count
4. **Code node** — flag posts where `comment_count` grew >5 since last sync (potential viral)
5. **Telegram notification** if any viral post detected

This pattern catches posts that gain traction overnight so you can engage early in the morning.

### Step 4 — Compute member_activity weekly

Once `posts_engagement` is populated daily, compute weekly per-member rollups:

```sql
-- Run as scheduled SQL in NocoDB or via your DB tool
INSERT INTO member_activity (skool_user_id, period_start, posts_count, comments_count, last_post_at)
SELECT
  author_id,
  DATE_TRUNC('week', NOW()) AS period_start,
  COUNT(*) FILTER (WHERE parent_id IS NULL) AS posts_count,
  COUNT(*) FILTER (WHERE parent_id IS NOT NULL) AS comments_count,
  MAX(created_at) AS last_post_at
FROM posts_engagement
WHERE created_at >= DATE_TRUNC('week', NOW())
GROUP BY author_id;
```

(Adapt to your DB's syntax. NocoDB supports SQL views over its tables.)

### Step 5 — Build dashboards

Now you have time-series data. Useful queries:

**Weekly active members (WAU)**:
```
COUNT(DISTINCT skool_user_id) FROM member_activity
WHERE period_start = DATE_TRUNC('week', NOW())
AND (posts_count > 0 OR comments_count > 0)
```

**Activation rate** (% of new joiners that post within 14 days):
```
SELECT
  DATE_TRUNC('week', joined_at) AS cohort_week,
  COUNT(*) AS joined,
  COUNT(*) FILTER (WHERE first_post_at <= joined_at + INTERVAL '14 days') AS activated,
  COUNT(*) FILTER (WHERE first_post_at <= joined_at + INTERVAL '14 days') * 100.0 / COUNT(*) AS activation_pct
FROM members_with_first_post
GROUP BY cohort_week
ORDER BY cohort_week DESC;
```

**Churn signal** (paid members who stopped posting):
```
SELECT first_name, last_name, username, tier, last_post_at
FROM members_snapshots
WHERE snapshot_date = (SELECT MAX(snapshot_date) FROM members_snapshots)
  AND tier > 0
  AND last_post_at < NOW() - INTERVAL '30 days'
ORDER BY tier DESC, last_post_at ASC;
```

These are the members worth a personal DM before they churn.

## Pricing estimate

For a community with 500 members and ~30 new posts/day:

| Workflow | Frequency | Skool calls | Cost/run | Monthly cost |
|---|---|---|---|---|
| Weekly member snapshot | Weekly | ~20 (paginated 500 members) | ~$0.11 | ~$0.50 |
| Daily post sync | Daily | ~5 (3 pages of 32 posts) | ~$0.02 | ~$0.60 |
| `auth:login` refresh | Every 3 days | 1 | ~$0.02 | ~$0.20 |
| **Total** | | | | **~$1.30/month** |

For a 5,000-member community: ~$10-15/month. Still trivial vs subscription analytics SaaS at $50-200/month.

## What you can do with this data

- **Membership health dashboard**: WAU, MAU, activation rate, churn trends week-over-week
- **Cohort retention curves**: how % of week-N joiners are still active at week N+4, N+8, N+12
- **Engagement quality**: posts per active member, comments per post, ratio of new conversations vs reposts
- **Identify ambassadors**: members with high `comments_count` but low `posts_count` — they're engaging others, perfect for community manager / mod role
- **Pre-churn outreach**: paid members whose `last_post_at` drops off, DM them before subscription renewal date
- **Content strategy**: which post categories generate most engagement, optimize editorial calendar

## Variation: research on communities you're a member of

The same `members:list` + `posts:list` pattern works for **any community where you have a valid login** — useful if you're studying what's working in adjacent communities before launching your own, or auditing the engagement of communities you've joined as a paying member.

A few rules of common sense:

- **Stay within Skool's ToS.** Only access data your account can already see by scrolling the UI — no auth bypasses, no paywalled content you didn't pay for, no scraping of admin-only fields.
- **Respect member privacy.** Aggregate metrics (engagement rates, posting cadence) are fine. Individual PII (emails, DMs, private notes) is not your data to use, even if technically reachable.
- **Don't republish individual members' content.** Insights from patterns ≠ copying others' posts verbatim.

The actor isn't a scraping tool — it's an automation layer over your own legitimate access. Use it that way.

## Caveats

- **Skool API doesn't expose payment data directly** — you can't see who paid when. Track tier changes (`tier` field in `members:list`) as proxy for paid conversions.
- **Comment-level data**: `posts:list` returns comment_count but not individual comments. For deep comment analysis, also sync with `posts:getComments` per post (more expensive).
- **GDPR / privacy**: you're exporting member PII. Make sure your members agree to this in your community guidelines, and store the data securely.
- **Skool can change response shapes**: pin actor version (`?build=0.3.20` in URL) instead of `latest` if you want reproducibility.

## Related

- [Members documentation](../docs/members.md) — full reference for `members:list` and related actions
- [Auto-approve members with n8n + GPT](auto-approve-members-n8n.md) — combines well with cohort tracking
- [Audit welcome thread](audit-welcome-thread-with-getcommentsfull.md) — find members who introduced themselves but never posted again
