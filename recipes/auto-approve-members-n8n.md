---
render_with_liquid: false
---

# Auto-approve Skool members with n8n + GPT-4o AI screening

End-to-end recipe: when someone applies to your Skool community, an n8n workflow runs a quality filter (LinkedIn check + GPT-4o AI screening of their application answer) and auto-approves the ones that pass — no manual review required.

> **🚀 Ready-to-import template available on n8n.io**
>
> [**→ Import the workflow on n8n.io**](https://n8n.io/workflows/14392-auto-approve-skool-community-members-with-gpt-4o-ai-screening/)
>
> The template includes the full Apify HTTP Request setup, GPT-4o screening node with prompt, error handling, and Telegram audit trail. Import it into your n8n instance and just plug in your credentials.

This is the exact pattern running in production for [Cágala, Aprende, Repite](https://www.skool.com/cagala-aprende-repite) — handles ~3 applicants/day, approves ~70% automatically, queues the rest for human review.

**Below**: the full walkthrough if you want to understand how it works (or build it from scratch in another tool).

## What you'll build

```
                                         ┌─────────────────────┐
[Skool] ──→ pending applicant ──→        │ n8n workflow        │
                                         │                     │
                                  ┌──→   │ 1. Schedule trigger │
                                  │      │    (every 15 min)   │
                                  │      │                     │
                                  │      │ 2. members:pending  │   ──→ Apify actor
                                  │      │    (read pending)   │
                                  │      │                     │
                                  │      │ 3. Filter           │
                                  │      │    (LinkedIn? bio?  │
                                  │      │     country? etc.)  │
                                  │      │                     │
                                  │      │ 4. members:approve  │   ──→ Apify actor
                                  │      │    (for each pass)  │
                                  │      │                     │
                                  │      │ 5. Notify Telegram  │
                                  │      │    (audit trail)    │
                                  │      └─────────────────────┘
                                  │
                                  └──── repeats every 15 min
```

## Prerequisites

- An n8n instance (self-hosted or cloud)
- Apify API token in n8n credentials (HTTP Header Auth: `Authorization: Bearer YOUR_TOKEN`)
- Skool admin credentials saved as n8n credentials (Email + Password type)
- Skool cookies cached somewhere (n8n's [Data Store](https://docs.n8n.io/data/), Redis, Postgres, Google Sheets — anything you can read/write from n8n)

## Step 1: Get cookies once

Add a **manual workflow** that runs `auth:login` and saves the cookies. Run this every 3 days (or whenever WAF_EXPIRED triggers your error handler).

**HTTP Request node** — Login:
- Method: `POST`
- URL: `https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token={{$credentials.apify.token}}`
- Body (JSON):
  ```json
  {
    "action": "auth:login",
    "email": "{{$credentials.skool.email}}",
    "password": "{{$credentials.skool.password}}",
    "groupSlug": "your-community-slug"
  }
  ```

**Set node** — Save cookies to data store:
- Save `{{ $json[0].cookies }}` to your store with key `skool_cookies`

## Step 2: Main workflow — auto-approve

Schedule this every 15 minutes.

### Node 2.1 — Schedule Trigger

Interval: every 15 minutes.

### Node 2.2 — Read cookies from store

(adapt to your store)

### Node 2.3 — HTTP Request — `members:pending`

- Method: `POST`
- URL: same as above
- Body:
  ```json
  {
    "action": "members:pending",
    "cookies": "{{ $node['Read cookies'].json.skool_cookies }}",
    "groupSlug": "your-community-slug"
  }
  ```

The response (in `dataset[0].members`) is an array of pending applicants:

```json
{
  "success": true,
  "members": [
    {
      "id": "request-id-32hex",
      "memberId": "user-id-32hex",
      "email": "applicant@example.com",
      "firstName": "Jane",
      "lastName": "Smith",
      "bio": "Founder, Buenos Aires, building a SaaS for vets",
      "linkedinUrl": "https://www.linkedin.com/in/janesmith",
      "country": "AR",
      "appliedAt": "2026-05-06T18:23:00Z",
      "applicationAnswer": "I want to learn how to fundraise"
    }
  ]
}
```

### Node 2.4 — Check error

**IF node**: `{{ $json[0].success }} === false`
- True branch: switch on `errorCode`
  - `WAF_EXPIRED` → trigger the login workflow + retry
  - else → notify Telegram, halt
- False branch: continue

### Node 2.5 — Split out members

Split the `members` array into individual items.

### Node 2.6 — Filter — your quality criteria

This is where you encode your community standards. Examples:

```javascript
// In an n8n Function or Filter node:
const m = $json;

// Required: LinkedIn URL present
if (!m.linkedinUrl) return false;

// Required: bio at least 30 chars
if (!m.bio || m.bio.length < 30) return false;

// Required: country in your target market
const allowedCountries = ['AR', 'CL', 'CO', 'MX', 'PE', 'ES'];
if (!allowedCountries.includes(m.country)) return false;

// Reject if applicationAnswer is empty or just spam
if (!m.applicationAnswer || m.applicationAnswer.length < 20) return false;

return true;  // pass
```

For more sophisticated filtering, you can call:
- LinkedIn enrichment (e.g. [Unipile](https://www.unipile.com/) or your own scraper) to verify the LinkedIn URL is real and check connection distance
- An LLM to score the application answer (e.g. "Is this answer specific or generic?")
- A NocoDB / Postgres lookup against a denylist of past spammers

### Node 2.7 — HTTP Request — `members:approve`

For each member that passes:

- Method: `POST`
- URL: same actor endpoint
- Body:
  ```json
  {
    "action": "members:approve",
    "cookies": "{{ $node['Read cookies'].json.skool_cookies }}",
    "groupSlug": "your-community-slug",
    "params": {
      "memberId": "{{ $json.memberId }}"
    }
  }
  ```

> **Note**: use `memberId`, not `id`. The `id` field on the pending request is the request itself; `memberId` is the canonical user ID Skool needs for the approve call.

### Node 2.8 — Notify Telegram (audit trail)

Send yourself a message: "Auto-approved: Jane Smith (LinkedIn: ...). Application: ..."

Optional: also send to a channel where the rest of your admin team can audit decisions.

## Step 3: Members that DON'T pass

Don't auto-reject — manual review is safer. Three options:

1. **Leave in pending** — they stay in Skool's queue, you review when you have time
2. **Notify you on Telegram** with their info → you click `/approve` or `/reject` reply commands
3. **Send to NocoDB / Airtable** with a "queue" status — review from your dashboard

The pattern at CAR uses option 2: a Telegram bot sends each non-auto-approved applicant with `/approve {memberId}` and `/reject {memberId}` quick actions.

## Production gotchas

### Rate limits

`members:approve` is a write action. Skool limits writes to ~25/min. If you have a sudden burst (e.g. you launched on Product Hunt), the actor's rate limiter blocks calls — they queue, not fail. If you go over Skool's hard limit you'll see `RATE_LIMIT` errors; back off 60s and retry.

### Idempotency

If your workflow runs twice for the same applicant (n8n retry, manual run, etc.), the second `members:approve` returns `SKOOL_API_ERROR` "cannot update to same role". This is a no-op — they're already approved. Filter by current role before calling approve, or treat the duplicate error as success.

### What if `members:pending` returns no one?

Empty list (`members.length === 0`) is normal — no applicants in queue. The `success` field is still `true`. Don't alert on empty.

### Cookies expiring mid-run

If your scheduled run hits `WAF_EXPIRED` mid-loop, only some approvals will succeed. The error handler should:

1. Trigger the login workflow → save new cookies
2. Re-run **only** the unprocessed members (not the whole `members:pending` again — that returns the new pending list which excludes the ones you already approved)

## Where to go next

- [Auto DM new members](auto-dm-new-members.md) — pair this with a personalized welcome message
- [Reply to unanswered posts](reply-unanswered-posts.md) — same pattern, applied to comments
- [Members documentation](../docs/members.md) — full member API reference

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "HowTo",
  "name": "Auto-approve Skool members with n8n + GPT-4o AI screening",
  "description": "An n8n workflow screens new Skool applicants with a LinkedIn check plus GPT-4o review of the application answer and auto-approves the ones that pass.",
  "totalTime": "PT30M",
  "tool": [
    {"@type": "HowToTool", "name": "Apify"},
    {"@type": "HowToTool", "name": "n8n"},
    {"@type": "HowToTool", "name": "GPT-4o"},
    {"@type": "HowToTool", "name": "Telegram bot"},
    {"@type": "HowToTool", "name": "Skool admin cookies"}
  ],
  "step": [
    {"@type": "HowToStep", "name": "Cache Skool cookies", "text": "Run a manual auth:login workflow and save the cookies to your data store, refreshing every ~3 days when WAF_EXPIRED fires."},
    {"@type": "HowToStep", "name": "Read pending applicants", "text": "On a 15-minute schedule, call members:pending to pull the queue with memberId, bio, LinkedIn, country and application answer."},
    {"@type": "HowToStep", "name": "Filter against quality criteria", "text": "Encode your community standards (LinkedIn present, bio length, target country, non-spam answer) or add LLM scoring, then approve passers with members:approve using memberId."},
    {"@type": "HowToStep", "name": "Route the rest to manual review", "text": "Leave non-passing applicants in pending and notify yourself on Telegram with an audit trail. Never auto-reject."}
  ]
}
</script>
