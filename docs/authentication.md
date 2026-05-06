# Authentication

How Skool auth actually works under the hood, why the cookies expire, and how to deal with the `x402-payment-required` error that confuses everyone.

## TL;DR

- Skool has **no public API key auth**. You authenticate as a user.
- The actor handles login via headless Playwright; you provide email + password.
- Login produces 3 cookies: `auth_token`, `client_id`, and `aws-waf-token`. **All three are required** for any subsequent call.
- The `aws-waf-token` rotates every **~3.5 days**. The `auth_token` is a long-lived JWT (~1 year). When WAF rotates you must re-login.
- Skool's Next.js dashboard ships a `buildId` that rotates roughly weekly. The actor catches stale-`buildId` errors and refreshes automatically — you don't need to handle this.

## Two auth modes

```
┌─────────────────────────────────────────────────────────────────┐
│ Mode A: email + password every call                             │
│   - Slow (~10s per run, Playwright login on every call)         │
│   - Higher cost (~$0.02 per run vs ~$0.005)                     │
│   - Simpler (no cookie management)                              │
│   - Use when: one-off scripts, very infrequent calls            │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ Mode B: auth:login once, cookies for everything else            │
│   - Fast (~2s per run, no browser)                              │
│   - Low cost                                                    │
│   - Cookies last ~3.5 days                                      │
│   - Use when: production workflows, n8n schedules, agents       │
└─────────────────────────────────────────────────────────────────┘
```

## Login flow (what `auth:login` actually does)

```
caller → action: auth:login (email, password, groupSlug)
              ↓
   Apify spins up an actor run
              ↓
   actor launches headless Chromium (xvfb-run)
              ↓
   navigates to skool.com → fills login form → submits
              ↓
   waits for redirect to dashboard (~5s)
              ↓
   extracts auth_token + client_id from cookies
              ↓
   extracts aws-waf-token from request headers
              ↓
   navigates to dashboard, scrapes window.__NEXT_DATA__.buildId
              ↓
   returns { cookies, buildId, expiresAt, expiresInDays }
```

The full login takes ~7-12 seconds the first time. Once you have cookies you don't repeat this until they expire (~3.5 days later).

## What's in the `cookies` string

```
auth_token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9....;
client_id=k1m9xz4pa...;
aws-waf-token=4f8a-1234567890abcdef-token...;
```

You pass this string verbatim as `cookies` in subsequent action calls. The actor uses these to authenticate every request to `api2.skool.com` and `_next/data`.

## The `x402-payment-required` "fake error"

If you see this error response from the actor at any time, on any action — **it's not a payment problem**.

```json
{
  "error": {
    "type": "x402-payment-required",
    ...
  }
}
```

This is Apify's generic response when the actor has its `notice: UNDER_MAINTENANCE` flag set. Apify activates this flag automatically when its **Automated Daily Quality Check** fails 2+ times in 3 days. The flag blocks ALL calls, regardless of build, regardless of caller, until cleared.

**As an actor caller**, you can't clear it — only the actor owner can:

```bash
curl -X PUT "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api?token=$APIFY_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"notice": null}'
```

**The good news**: this actor is designed to **never trip that flag**. The default action is `system:health` (a no-auth, no-Skool, deterministic 1-item ping). Apify's daily quality check passes every day. If you ever see the flag active, [open an issue](https://github.com/ctala/skool-api-docs/issues) and it'll get cleared within minutes.

## Cookie expiry & detection

When the WAF token expires (~3.5 days after login), any call returns:

```json
{
  "success": false,
  "errorCode": "WAF_EXPIRED",
  "errorCategory": "auth_error",
  "statusCode": 403,
  "retryable": true,
  "hint": "Cookies expired (~3.5 days TTL). Re-run auth:login to get fresh cookies."
}
```

Your handler should:

1. Detect `errorCode === "WAF_EXPIRED"` (or `errorCategory === "auth_error"`)
2. Re-run `auth:login` with email + password
3. Save the new cookies
4. Retry the original action

**Don't catch and silently swallow auth errors.** If your stored credentials are wrong, you'll burn quota retrying.

## buildId rotation

Skool's web app ships with a `buildId` that the SSR data endpoints (`/_next/data/{buildId}/...`) require. Skool deploys ~weekly and rotates the buildId. The actor handles this automatically:

1. Read action calls `/_next/data/{cached_buildId}/slug.json` → gets 404
2. Actor catches `BuildIdStaleError`, fetches the dashboard HTML, extracts new `buildId`
3. Retries the original call → success

You'll see `BUILDID_STALE` in failure payloads only if the auto-retry itself fails (very rare). Hint: re-run `auth:login`.

## Rate limits

Skool enforces rate limits per-user, not per-app:

- **Reads**: ~60 requests/min (safe ceiling, Skool starts throttling around 90)
- **Writes**: ~20-30 requests/min (Skool returns `429 Too Many Requests` above this)

The actor has a built-in token-bucket rate limiter that enforces 60 reads + 25 writes per minute. If your usage spikes above that, calls block briefly (queue-style) rather than fail.

If you do hit Skool's limit (e.g. multi-actor concurrent calls from same account), you get:

```json
{
  "errorCode": "RATE_LIMIT",
  "errorCategory": "rate_limited",
  "retryable": true,
  "hint": "Reduce request frequency. Wait a few minutes and retry."
}
```

## Multiple accounts

You can authenticate as different Skool users by running `auth:login` with different credentials and tagging the resulting cookies. Each cookie set is independent — they don't conflict.

Common pattern: one cookie set for read-only calls (a low-permission account), one for write calls (admin). This isolates blast radius if a cookie leaks.

## What `auth:login` does NOT do

- ❌ Doesn't bypass 2FA. If the account has 2FA enabled, login will hang (Playwright stuck on the 2FA prompt). Use a dedicated automation account without 2FA.
- ❌ Doesn't bypass captchas. Skool occasionally serves captchas to suspicious sessions. If login keeps failing with `AUTH_ERROR`, log into the same account from a regular browser first to clear the suspicious-session flag.
- ❌ Doesn't grant any access you don't already have. You authenticate as a user; you can only act on communities you're a member or admin of.

## See also

- [Error handling](error-handling.md) — full catalog of `errorCode` values
- [Getting started](getting-started.md) — first call walkthrough
