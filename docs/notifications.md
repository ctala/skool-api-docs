# Notifications

Read the logged-in account's notification feed and mark items as read. This is the fastest way to catch **mentions, replies, and comments directed at you** — the ones a feed poll can miss because they live deep inside old threads.

> **Data model:** a notification *is* a message in Skool. That's why the read endpoint is `/self/notifications` but the mark endpoints live under `/messages`, and why `GET /notifications` returns 404. Each item's real payload arrives as a JSON string that the actor parses for you.

Notifications are **cross-group**: the feed returns items from every community the account belongs to, not just `groupSlug`. Filter by `groupId` on each item if you only want one community.

## Read actions

### `notifications:list` — list notifications (newest first)

```json
{
  "action": "notifications:list",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "limit": 30, "type": "all", "unreadOnly": false }
}
```

| Param | Type | Description |
|---|---|---|
| `limit` | number | Items per page. **Max 30** (higher returns `HTTP 400 "invalid limit"`; the actor clamps it for you). |
| `type` | string | Server-side filter. `all` (default) returns every kind. |
| `cursor` | string | Opaque cursor from a previous response's `cursor`, to page forward. |
| `unreadOnly` | boolean | Client-side filter: return only unread items. |

Response:

```json
{
  "notifications": [
    {
      "id": "74e38949dc2c4d0a81f3ac615f383d8b",
      "action": "mention-comment",
      "unread": true,
      "createdAt": "2026-07-09T10:06:48.383781Z",
      "groupId": "32-char-hex",
      "title": "Jane Smith",
      "content": "@you great point — how did you handle the pricing?",
      "link": "/your-community/some-post?p=675f6e3e",
      "imageUrl": "https://assets.skool.com/f/.../-md.jpg"
    }
  ],
  "hasMore": true,
  "cursor": ":321d1d19...:1:2026-07-09T09:17:57.718052Z"
}
```

- `title` — the actor/sender name or the notification header (e.g. `"New membership request!"`).
- `content` — the main text payload: a member name, a comment snippet, or a post title.
- `link` — a **relative deep-link** to the exact target. For comment/mention types it points at the post plus `?p=<commentId>` — prepend `https://www.skool.com` to open it.
- Paginate with `cursor`: pass `cursor` back and keep going while `hasMore` is `true`.

## Write actions

### `notifications:markRead` — mark ONE as read

```json
{
  "action": "notifications:markRead",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "id": "notification-id", "createdAt": "2026-07-09T10:06:48.383781Z" }
}
```

`createdAt` is the value from the same notification — Skool's endpoint echoes it back in the request body. Returns `{ "success": true, "id": "...", "action": "marked-read" }`.

### `notifications:markAllRead` — mark ALL as read

```json
{
  "action": "notifications:markAllRead",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {}
}
```

Marks every notification for the current group as read. Returns `{ "success": true, "action": "marked-all-read" }`.

> ⚠️ **The effect is deferred.** The call returns `200` immediately, but Skool propagates the read state a few seconds later — not synchronously. Don't assert `unread === 0` right after the call; poll `notifications:list` with `unreadOnly` until it clears.

## Notification types

`action` values seen in the wild (not exhaustive — Skool adds more):

| `action` | Meaning | Actionable? |
|---|---|---|
| `mention-comment` | You were @mentioned in a comment | ✅ usually needs a reply |
| `comment` | New comment on a post you're in/following | ✅ often needs a reply |
| `upvote-post` / `upvote-post-bundled` | Someone liked your post/comment (bundled = several) | — signal only |
| `new-post-user-following` | New post from someone you follow | — informational |
| `membership-request` | Someone applied to join (owners/admins) | handle via [members:pending](members.md) |

A practical split for an engagement bot: treat `mention-*`, `reply-*`, and `comment` as **actionable** (draft a reply), and `upvote-*`, `new-post-*`, `membership-request` as **informational** (log or route elsewhere).

## Common gotchas

### `/notifications` returns 404
The resource is `message`, not `notification`. Use `notifications:list` (the actor calls `/self/notifications` under the hood).

### `limit` above 30 fails
Skool caps the page at 30 and rejects larger values with `HTTP 400 "invalid limit"`. The actor clamps to 30, but if you call the endpoint directly, keep it ≤ 30 and paginate with `cursor`.

### markAllRead looks like it did nothing
See the deferred-effect note above — the read state lands a few seconds after the `200`. Poll before concluding it failed.

## See also

- [Posts & Comments](posts.md) — reply to the mention/comment a notification points at
- [Members](members.md) — handle `membership-request` notifications
- [Actions Reference](actions.md) — every action at a glance
