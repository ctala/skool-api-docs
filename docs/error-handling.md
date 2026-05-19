---
render_with_liquid: false
---

# Error Handling

The actor **never throws**. Every error — expected or not — becomes a structured `{success:false}` payload pushed to the dataset, and the run terminates `SUCCEEDED`. Your code is responsible for inspecting the payload.

## Why never-throw

Apify's automated quality control treats `FAILED` runs as a signal that the actor is broken. Enough `FAILED` runs in a 3-day window flips a `notice: UNDER_MAINTENANCE` flag that **blocks all calls** to the actor. Returning structured failures in dataset (with `SUCCEEDED` run status) sidesteps that mechanism — production callers stay unaffected by transient errors.

Your integration **must** check `dataset[0].success` before treating the response as a result.

## Failure payload shape

```json
{
  "success": false,
  "action": "posts:createComment",
  "error": "post not found: 3bc910b1",
  "errorCode": "NOT_FOUND",
  "errorCategory": "not_found",
  "statusCode": 404,
  "retryable": false,
  "hint": "Verify the ID provided in params. If it was valid before, the resource may have been deleted."
}
```

Fields:

| Field | Type | Description |
|---|---|---|
| `success` | `false` | Always `false` for errors |
| `action` | string | Action that failed (`posts:create`, `members:approve`, etc.) |
| `error` | string | Raw error message from Skool / network / actor |
| `errorCode` | string | Stable, machine-readable code (see catalog below) |
| `errorCategory` | string | High-level category for routing logic |
| `statusCode` | number | HTTP status when applicable (404, 422, 429, etc.) |
| `retryable` | boolean | Whether retrying the same call may succeed |
| `hint` | string | Human-readable suggestion for fixing the issue |
| `stack` | string | Stack trace, present only for `unknown_error` (genuine bugs) |

## Error categories

| `errorCategory` | What triggers it | `retryable` typically | Recommended action |
|---|---|---|---|
| `input_validation` | Missing or malformed params (`postId` not provided, `action` missing, etc.) | `false` | Fix the input and retry |
| `auth_error` | Login failed, captcha, bad password, expired WAF token | `true` | Re-run `auth:login` to get fresh cookies |
| `not_found` | Skool returned 404 for a referenced resource (post, member, course) | `false` | Verify the ID; resource may have been deleted |
| `rate_limited` | 429 from Skool (writes/min ceiling hit) | `true` | Back off 30-60s, then retry |
| `skool_api_error` | 4xx/5xx from Skool other than auth/404/429 | varies | Inspect `error` and `hint` to fix params; if 5xx, retry later |
| `scraping_error` | Stale `buildId` couldn't auto-refresh | `true` | Re-run `auth:login` to refresh the cached buildId |
| `network_error` | Fetch timeout, abort, DNS failure, connection reset (TCP/HTTP layer) | `true` | Transient; retry after 30-60s |
| `unknown_error` | Anything not classified above (real bug) | `true` | Inspect `stack` field + Apify run logs; [open an issue](https://github.com/ctala/skool-api-docs/issues) if reproducible |

## errorCode catalog

### Auth-related

| `errorCode` | Meaning | Fix |
|---|---|---|
| `AUTH_ERROR` | Login failed (wrong password, captcha, 2FA prompt) | Verify credentials in a browser session first |
| `WAF_EXPIRED` | Stored cookies older than ~3.5 days | Re-run `auth:login` |
| `BUILDID_STALE` | Skool deployed a new dashboard, `buildId` cache stale | Re-run `auth:login` |

### Skool API validation

| `errorCode` | Meaning | Fix |
|---|---|---|
| `MISSING_CATEGORY` | Community requires posts to have a category | Pass `params.labelId` (get values via `groups:get`) |
| `TITLE_TOO_LONG` | Title exceeds Skool's 50-char limit (UTF-16; emojis count as 2) | Trim `params.title` |
| `INSUFFICIENT_TIER` | Account lacks the `min_tier` required to read this resource | Use admin credentials |
| `SKOOL_API_ERROR` | Generic 4xx from Skool not matched above (e.g. "cannot update to same role") | Inspect `error` for details |

### Resource state

| `errorCode` | Meaning | Fix |
|---|---|---|
| `NOT_FOUND` | Resource ID doesn't exist (anymore) | Double-check ID |
| `RATE_LIMIT` | Hit Skool's writes/min ceiling | Wait 60-120s, retry |

### Transport

| `errorCode` | Meaning | Fix |
|---|---|---|
| `NETWORK_ERROR` | Fetch failure (timeout, DNS, ECONN*) | Transient; retry |
| `INPUT_VALIDATION` | Required field missing in your input | Fix input |

### Catch-all

| `errorCode` | Meaning | Fix |
|---|---|---|
| `UNKNOWN_ERROR` | Real bug. Includes `stack` field | [Open an issue](https://github.com/ctala/skool-api-docs/issues) with the run ID |

## Recipes for handling errors

### JavaScript / TypeScript

```javascript
async function callActor(input) {
  const r = await fetch(
    `https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=${APIFY_TOKEN}`,
    { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(input) },
  );
  const items = await r.json();
  return items[0]; // single-action run = single item
}

const result = await callActor({ action: 'posts:create', cookies, groupSlug, params: { title, content } });

if (result.success === false) {
  console.error(`[${result.errorCategory}/${result.errorCode}] ${result.error}`);
  console.error(`Hint: ${result.hint}`);

  if (result.errorCode === 'WAF_EXPIRED') {
    // Re-login, retry
    const login = await callActor({ action: 'auth:login', email, password, groupSlug });
    cookies = login.cookies;
    // retry original
  } else if (result.retryable) {
    await new Promise(r => setTimeout(r, 30000));
    // retry
  } else {
    throw new Error(`Skool API rejected: ${result.error}`);
  }
} else {
  // success — use result.post, result.posts, result.members, etc.
}
```

### n8n

In an HTTP Request node calling the actor's `run-sync-get-dataset-items` endpoint:

1. Add an **IF node** after the HTTP Request:
   - Condition: `{{ $json[0].success }}` equals `false`
2. **True branch** (failure):
   - Switch on `{{ $json[0].errorCode }}`
   - For `WAF_EXPIRED` → call `auth:login` flow → store new cookies → loop back
   - For `RATE_LIMIT` → Wait node 60s → loop back
   - For everything else → log + alert
3. **False branch** (success): continue normal flow

### Make.com

Use a **Router** module after the actor call:

- Filter 1: `1.[].success = false` → Error handler scenario (mirrors n8n logic above)
- Filter 2: `1.[].success = true` → Continue normal flow

## What's NOT an error

The actor returns `success: true` even for **empty results**. This is by design:

```json
{ "success": true, "posts": [], "total": 0, "hasMore": false }
```

If you're checking "did the post exist?" — look at `posts.length`, not `success`. `success` only tells you the action **executed cleanly**.

## Reporting bugs

If you hit `errorCategory === "unknown_error"`, that's a real bug. Please [open an issue](https://github.com/ctala/skool-api-docs/issues/new?template=bug-report.md) with:

- The full failure payload (including `stack`)
- The Apify run ID (visible in the actor console)
- The action + params (redact secrets)
- What you expected vs what happened

Bugs get fixed fast — this actor is used in production daily.
