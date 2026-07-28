---
title: "Fix members:export 401 email verification required (verified client_id)"
description: "Since 30 June 2026 Skool treats the member CSV export as a sensitive action: it needs an email-verified client_id that lapses every ~2 days. Full flow, plus how to automate the code with a programmatic inbox."
slug: /recipes/fix-members-export-email-verification
type: recipe
funnel: A
section: Recipes
last_updated: 2026-07-28
render_with_liquid: false
---

# Fix `members:export` — "401 email verification required"

Your cookies are fine. `auth:login` works, `posts:list` works, `system:debug` works — and `members:export` alone comes back with `400 invalid client ID` or `401 email verification required`.

That is not a broken export. On **30 June 2026** Skool reclassified the member CSV bulk export as a **sensitive action**. Two things changed at once:

1. The export request must now carry a `client_id` **in the query string**.
2. That `client_id` must be **email-verified** — Skool emails a numeric code, and the id only counts as trusted once you submit it.

Nothing else about authentication changed, which is exactly why the failure looks so isolated: every other endpoint keeps working on the same cookies.

## Quick reference (TL;DR for agents)

| | |
|---|---|
| **Symptom** | `members:export` returns `400 invalid client ID` or `401 email verification required` while every other action works |
| **Cause** | Skool's sensitive-action gate: the export needs an email-verified `client_id` |
| **Fix** | Pin one `client_id`, verify it once with a code Skool emails you, reuse it |
| **Recurring?** | Yes — verification lapses after **~2 days** |
| **Automatable?** | Fully. The code arrives by email, so a programmatic inbox closes the loop |
| **Actor version** | `0.3.34+` sends the `client_id`. Verifying it is on your side (for now) |

## Why the error changes shape

Depending on which actor build you are on, the same root cause shows up differently. Both mean "this client_id is not trusted":

| Error | What it means |
|---|---|
| `400 — invalid client ID` | No `client_id` reached the endpoint at all. Actor builds before `0.3.34` |
| `401 — email verification required` | A `client_id` arrived, but it has never been verified — or its verification lapsed |

If you are seeing the `400`, upgrade first: builds from `0.3.34` onward forward the `client_id` from your cookies. Then work through the `401` below.

## The trap: `auth:login` gives you a *new* client_id every time

This is the part that makes the problem feel unfixable.

Each `auth:login` call mints a **fresh, random `client_id`**, which Skool treats as a brand-new, untrusted device. So the intuitive fix — "log in again to get clean cookies" — guarantees failure: you verify one id, then hand the export a different, unverified one on the next run.

**Pin one `client_id` and keep reusing it.** Verification binds to the *account*, not to the session or the auth token, so a verified id keeps working across logins until it lapses.

## Prerequisites

- Admin or owner rights on the community (export is admin-only)
- Cookies for that account: `auth_token`, `client_id`, `aws-waf-token`
- Access to the mailbox that receives Skool's mail

## Step 1 — Get a client_id and hold on to it

Call `auth:login` **once**, take the `client_id` out of the returned cookie string, and store it wherever you keep config:

```bash
curl -s -X POST "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=$APIFY_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "action": "auth:login",
    "groupSlug": "your-community",
    "email": "you@example.com",
    "password": "your-password"
  }'
```

The response contains a `cookies` string of the form `auth_token=…; client_id=…; aws-waf-token=…`. **The `client_id` in it is the one you are about to verify.**

## Step 2 — Trigger the verification code

Two plain HTTP calls against `api2.skool.com`, using those same cookies. Both require the full cookie triple, the `x-aws-waf-token` header, and a browser User-Agent — Skool rejects them otherwise.

```bash
curl -s -X POST "https://api2.skool.com/auth/email-verify-init" \
  -H "Content-Type: application/json" \
  -H "Cookie: auth_token=$AUTH_TOKEN; client_id=$CLIENT_ID; aws-waf-token=$WAF_TOKEN" \
  -H "x-aws-waf-token: $WAF_TOKEN" \
  -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36" \
  -d "{\"client_id\": \"$CLIENT_ID\"}"
```

Expect `200 {"verified": false}`. That response means *the code was sent*, not that anything failed.

Skool emails a numeric code with a subject like `1234 is your Skool email verification code`. **It expires in about 30 minutes.**

## Step 3 — Submit the code

```bash
curl -s -X POST "https://api2.skool.com/auth/email-verify" \
  -H "Content-Type: application/json" \
  -H "Cookie: auth_token=$AUTH_TOKEN; client_id=$CLIENT_ID; aws-waf-token=$WAF_TOKEN" \
  -H "x-aws-waf-token: $WAF_TOKEN" \
  -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36" \
  -d "{\"client_id\": \"$CLIENT_ID\", \"code\": \"1234\"}"
```

`200` means that `client_id` is now trusted for your account.

## Step 4 — Run the export with those cookies

Pass the cookie string containing the **verified** `client_id`:

```bash
curl -s -X POST "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=$APIFY_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "action": "members:export",
    "groupSlug": "your-community",
    "cookies": "auth_token=…; client_id=…; aws-waf-token=…",
    "params": { "status": "active" }
  }'
```

From here the normal [export recipe](export-skool-members-csv.md) applies.

## Step 5 — Automate it, because it lapses every ~2 days

This is not one-time setup. Verification expires after roughly two days, and when it does the export starts failing again — silently, from the perspective of a nightly job.

The good news: **the code arrives by email, so nothing here needs a human.** The loop is:

1. Run the export.
2. If it fails with `email verification required` (or `invalid client ID`), fire `email-verify-init`.
3. Read the code from the inbox.
4. Post `email-verify`.
5. Retry the export **once**. If it still fails, stop and alert — do not degrade silently.

Any programmatic inbox works: Gmail API, plain IMAP, or a dedicated domain on Cloudflare Email Routing pointed at a worker. What matters is not the provider but the filtering:

- Only accept mail **from `skool.com`**.
- Only accept mail that arrived **after** you fired `email-verify-init`. Reusing a code from an earlier attempt is the most common way this loop breaks — the old code is expired, the call fails, and the retry logic loops.
- Discard anything you cannot reliably timestamp.

Reference implementation shape (Node):

```js
// Read the body ONCE. Calling r.json() and then r.text() throws
// "body stream already read" — a real gotcha when you add logging here.
const res = await fetch(url, { method: 'POST', headers, body });
const raw = await res.text();
const data = JSON.parse(raw);
```

### Fail closed, not open

If verification cannot be completed, **abort the job** rather than continuing with partial data. An export that silently returns nothing looks identical to a community that lost all its members — and if you are reconciling paid status from it, that difference matters a lot.

## Gotchas

- **Do not call `auth:login` before every run.** It mints a new unverified `client_id` and puts you back at square one. This is the single most common cause of "I verified it and it still fails".
- **Verification binds to the account, not the session.** A verified `client_id` survives new logins and new `auth_token`s.
- **The code expires in ~30 minutes**, and each `email-verify-init` invalidates the previous one.
- **All calls need the browser User-Agent + `x-aws-waf-token`.** Missing either returns a WAF rejection that looks nothing like an auth error.
- **`members:export` is admin-only.** A regular member gets a permissions error, not a verification prompt.

## Related

- [Export Skool members to CSV](export-skool-members-csv.md) — the export itself, once verification is sorted
- [Authentication](../docs/authentication.md) — cookie triple, WAF token TTL, `auth:login`
- [members actions](../docs/members.md) — full reference

[**→ Open the actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=fix-members-export-email-verification&fpr=cristian)

*New to Skool? [Launch your community here](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "HowTo",
  "name": "Fix members:export email verification required on Skool",
  "description": "Resolve the 401 email verification required error on Skool's member CSV export by pinning and verifying a client_id, and automate the recurring re-verification.",
  "totalTime": "PT10M",
  "tool": [
    {"@type": "HowToTool", "name": "Apify"},
    {"@type": "HowToTool", "name": "Skool admin cookies"},
    {"@type": "HowToTool", "name": "A programmatic inbox"}
  ],
  "step": [
    {"@type": "HowToStep", "name": "Pin a client_id", "text": "Call auth:login once and keep the client_id from the returned cookie string. Do not call auth:login before every run: it mints a new unverified client_id."},
    {"@type": "HowToStep", "name": "Trigger the code", "text": "POST to api2.skool.com/auth/email-verify-init with the client_id, the cookie triple, x-aws-waf-token and a browser User-Agent. Skool emails a numeric code valid for about 30 minutes."},
    {"@type": "HowToStep", "name": "Submit the code", "text": "POST to api2.skool.com/auth/email-verify with the same client_id and the code. A 200 means the client_id is trusted for the account."},
    {"@type": "HowToStep", "name": "Run the export", "text": "Call members:export passing the cookie string that contains the verified client_id."},
    {"@type": "HowToStep", "name": "Automate re-verification", "text": "Verification lapses after about two days. Detect the error, re-run the verify cycle reading the code from a programmatic inbox, accepting only mail from skool.com received after the trigger, and retry the export once."}
  ]
}
</script>
