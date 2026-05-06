# Members

Manage your Skool community membership: list active members, see who's pending approval, approve/reject/ban with optional batching.

## Read actions

### `members:list` — active members

```json
{
  "action": "members:list",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "limit": 50, "page": 1 }
}
```

Response:

```json
{
  "success": true,
  "members": [
    {
      "id": "member-id-32hex",
      "userId": "32-char-hex",
      "firstName": "Jane",
      "lastName": "Smith",
      "email": "jane@example.com",
      "bio": "Founder, Buenos Aires",
      "level": 2,
      "minTier": 2,
      "country": "AR",
      "joinedAt": "2026-04-12T10:30:00Z",
      "lastActiveAt": "2026-05-06T18:00:00Z",
      "linkedinUrl": "https://www.linkedin.com/in/janesmith",
      "role": "member"
    }
  ],
  "page": 1,
  "total": 484,
  "hasMore": true
}
```

`role` values: `member`, `admin`, `owner`.

### `members:pending` — pending applicants

```json
{
  "action": "members:pending",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "limit": 50 }
}
```

Returns members in the approval queue. Each item has the same shape as `members:list` plus:

- `applicationAnswer` — what they wrote in your apply form
- `appliedAt` — timestamp
- `id` — request ID (use for routing in your queue, NOT for `approve` calls)
- `memberId` — canonical user ID (use this for `approve`/`reject`)

> **Important**: pass `memberId`, NOT `id`, to write actions. The `id` field on a pending request is the request itself; `memberId` is what Skool's role API needs.

## Write actions

### `members:approve` — approve a pending applicant

```json
{
  "action": "members:approve",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "memberId": "32-char-hex" }
}
```

### `members:reject` — reject a pending applicant

```json
{
  "action": "members:reject",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "memberId": "32-char-hex" }
}
```

### `members:ban` — ban an active member

```json
{
  "action": "members:ban",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "memberId": "32-char-hex" }
}
```

Banned members lose access immediately and can't re-apply. Skool keeps the ban record indefinitely.

### `members:batchApprove` — approve N members in one run

```json
{
  "action": "members:batchApprove",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "memberIds": ["id1", "id2", "id3"]
  }
}
```

Each approval is an independent write call internally; the actor handles rate limiting. Cost is `$0.01 × N`. Failures don't block the batch — the response contains a per-item result array.

```json
{
  "success": true,
  "results": [
    { "memberId": "id1", "ok": true },
    { "memberId": "id2", "ok": false, "error": "...", "errorCode": "NOT_FOUND" },
    { "memberId": "id3", "ok": true }
  ],
  "approved": 2,
  "failed": 1
}
```

## Roles

Skool tracks 3 roles: `member`, `admin`, `owner`. The actor's current write actions cover `member` lifecycle (approve/reject/ban). Promoting a member to admin is **not yet exposed** — for now, do it through the Skool UI.

## Tiers (pricing-based access)

If your community has paid tiers, members have a `minTier` field representing their highest paid tier:

| `minTier` | Typical meaning | Convention used in CAR |
|---|---|---|
| `0` | Free | Standard (free) |
| `1` | (varies per community) | reserved |
| `2` | First paid tier | Premium |
| `3` | Second paid tier | VIP |

Tier mapping is per-community. Use `groups:get` to read the current tier definitions for your group.

## Common gotchas

### Approving an already-approved member

Returns `SKOOL_API_ERROR` with `error: "cannot update to same role"`. Treat this as a no-op, not a real failure — they're already in.

### Banning the owner

Skool refuses (correctly). You can't ban yourself or your co-owners.

### `members:list` cursor pagination

Skool's SSR returns members in pages but the cursor is opaque. Use `page: N` until `hasMore === false`.

### Email is not always present

For some communities (privacy-conscious ones), `members:list` may not return `email`. Pending applicants typically include it.

### LinkedIn URL is self-reported

The `linkedinUrl` on a member or pending applicant is whatever they pasted into the apply form. Skool doesn't verify. If you're auto-approving based on LinkedIn presence, **also verify the URL is reachable + matches the name** (use a LinkedIn enrichment API or your own scraper).

## Recipes

- [**Auto-approve members with n8n + GPT-4o**](../recipes/auto-approve-members-n8n.md) — production-grade approval pipeline

## See also

- [Auto DM new members](../recipes/auto-dm-new-members.md)
- [Groups](groups.md) — for group-level settings
