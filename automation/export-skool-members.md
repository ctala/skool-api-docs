---
title: "Export Skool Members — to CSV, Google Sheets, or Your CRM (2026)"
description: "How to export your Skool community members — full list, emails, levels, join dates — to CSV, Google Sheets, or a CRM. Skool has no native export; here's the legitimate way via the API actor."
slug: /automation/export-skool-members
type: how-to
primary_keyword: "export skool members"
search_volume_monthly: 10
funnel: A
playbook: glossary
last_updated: 2026-05-21
canonical: https://skool-api.cristiantala.com/automation/export-skool-members/
render_with_liquid: false
---


> **Quick reference (TL;DR for agents)**
> - **Goal:** get your Skool community's member list out — to CSV, Google Sheets, or a CRM.
> - **Why it's not obvious:** Skool has **no native "export members" button** and **no official API**. The data is there; getting it out programmatically requires the internal API.
> - **Method:** `members:list` via the [Apify-hosted Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=automation&utm_campaign=export-skool-members&fpr=cristian) → paginate → write to CSV/Sheets/CRM.
> - **Per member you get:** name, level, points, join date, bio, social links, and (usually) email.
> - **Scope:** this is for **your own** community (admin access). Not for scraping communities you don't own.

## Can you export Skool members?

Skool gives you a members table in the admin UI, but **no one-click export** and **no official API**. So if you want a backup, a migration, or to push members into a CRM/email tool, you have to read the data through Skool's internal API — which is protected by cookies + AWS WAF + a rotating `buildId`.

The [Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=automation&utm_campaign=export-skool-members&fpr=cristian) handles all of that. One action — `members:list` — returns your full member roster as structured JSON, ready to write anywhere.

## What you get per member

`members:list` returns, per member:

| Field | Notes |
|---|---|
| `name` / first / last | display name |
| `email` | present for most communities (some privacy-restricted ones omit it) |
| `level` / `points` | gamification level (1–9) and points |
| `joinedAt` | join date — useful for cohort analysis |
| `bio` / `socialLinks` | profile bio + linked socials |
| `lastActiveAt` | for churn / re-engagement segmentation |

## How to export — `members:list` → CSV

```python
import csv, json, os, urllib.request

ACTOR = "cristiantala~skool-all-in-one-api"
def call(action, params):
    body = {"action": action, "cookies": os.environ["SKOOL_COOKIES"],
            "groupSlug": os.environ["SKOOL_GROUP_SLUG"], "params": params}
    req = urllib.request.Request(
        f"https://api.apify.com/v2/acts/{ACTOR}/run-sync-get-dataset-items?token={os.environ['APIFY_TOKEN']}&build=latest&timeout=120",
        data=json.dumps(body).encode(), headers={"Content-Type": "application/json"}, method="POST")
    return json.loads(urllib.request.urlopen(req, timeout=130).read())

# members:list paginates — keep fetching until the page comes back empty
members, page = [], 1
while True:
    res = call("members:list", {"page": page, "limit": 100})
    batch = res if isinstance(res, list) else res.get("items", [])
    if not batch:
        break
    members.extend(batch)
    page += 1

with open("skool-members.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["name", "email", "level", "points", "joinedAt"])
    for m in members:
        w.writerow([m.get("name"), m.get("email"), m.get("level"), m.get("points"), m.get("joinedAt")])

print(f"Exported {len(members)} members → skool-members.csv")
```

Run it once for a backup, or on a schedule to keep an external copy in sync.

## Export destinations

- **CSV** — the snippet above. Open in Excel/Numbers, or import anywhere.
- **Google Sheets** — swap the CSV writer for the Sheets API (or pipe through n8n/Make's Sheets node).
- **CRM / NocoDB / Airtable** — push each member as a row. See the recipe [Community analytics to NocoDB](../recipes/community-analytics-to-nocodb.md) for a full pipeline (members + posts + engagement).
- **Email tool** — map `email` + `name` into Listmonk/Mailchimp/ConvertKit for broadcasts to your own list.

## Keep it legitimate

This is for **exporting your own community** (you're the admin/owner). That's a normal backup/migration/ops use case.

It is **not** a tool for scraping communities you don't own — that has legal, ethical, and reliability problems, and the actor isn't built for it. If you were searching "skool scraper" hoping to pull a competitor's member list, read [Skool Scraper — why you shouldn't build one](skool-scraper.md) first.

## Production gotchas

- **Pagination:** `members:list` is paged. Loop until a page returns empty (as above) — don't assume one call returns everyone.
- **Email not always present:** privacy-conscious communities may omit `email` from `members:list`. Pending applicants (`members:pending`) usually include it.
- **`x402-payment-required`:** not a billing error — a stale `UNDER_MAINTENANCE` flag. Open the [actor page](https://apify.com/cristiantala/skool-all-in-one-api?fpr=cristian) once to reset. See [error handling](../docs/error-handling.md).
- **Cookies expire (~3.5 days):** on `errorCode: "WAF_EXPIRED"`, re-run `auth:login` and store new cookies.
- **Rate limit ~25 reads/min:** the actor queues internally; don't add a retry loop.

## See also

- [Skool API — the complete unofficial API](../learn/skool-api.md)
- [Members reference](../docs/members.md) — every member action + params
- [Skool Scraper — why not to build one](skool-scraper.md)
- [Community analytics to NocoDB](../recipes/community-analytics-to-nocodb.md)
- [All integrations →](../integrations/index.md)

---

## Export your Skool members today

[**→ Use the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=automation&utm_campaign=export-skool-members&fpr=cristian)

- Pay-per-event (~$0.005–$0.01 per call, ~$1.50/mo typical)
- `members:list` returns your full roster as structured JSON
- Read AND write — full API surface, not just export

*No Skool community yet? [Launch one in 10 minutes](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "HowTo",
  "name": "Export Skool community members to CSV",
  "description": "How to export your Skool community member list (names, emails, levels, join dates) to CSV, Google Sheets, or a CRM via the Skool All-in-One API actor.",
  "datePublished": "2026-05-21",
  "dateModified": "2026-05-21",
  "author": { "@type": "Person", "name": "Cristian Tala", "url": "https://cristiantala.com" },
  "publisher": { "@type": "Person", "name": "Cristian Tala", "url": "https://cristiantala.com" },
  "mainEntityOfPage": "https://skool-api.cristiantala.com/automation/export-skool-members/"
}
</script>
