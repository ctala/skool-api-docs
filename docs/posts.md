# Posts & Comments

Skool's most important resource — and the one with the most quirks. Read this once and you'll skip a week of head-scratching.

## The single most important fact

**Posts and comments are the same object.**

In Skool's data model:

```
Post:    { id, rootId: id,        parentId: null      }   post_type: "generic"
Comment: { id, rootId: postId,    parentId: postId    }   post_type: "comment"  ← top-level comment
Reply:   { id, rootId: postId,    parentId: commentId }   post_type: "comment"  ← nested reply
```

There is **no `/comments` endpoint**. Everything goes through `/posts`. To create a comment, you call the same action you'd use to create a reply: `posts:createComment`. The `rootId` and `parentId` you pass determine whether it's a top-level comment or a nested reply.

## Read actions

### `posts:list` — list posts (paginated)

```json
{
  "action": "posts:list",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "page": 1,
    "sort": "newest-cm",
    "limit": 20
  }
}
```

| Param | Type | Default | Notes |
|---|---|---|---|
| `page` | number | 1 | 1-indexed |
| `sort` | string | `"newest-cm"` | Also accepts `"top"`, `"trending"`, `"oldest"`. May not affect SSR results in all cases. |
| `limit` | number | 32 | Skool's max page size; the actor doesn't enforce a higher cap |

Response:

```json
{
  "success": true,
  "posts": [
    {
      "id": "32-char-hex",
      "title": "Post Title",
      "content": "Plain text content",
      "author": { "id": "...", "firstName": "John", "lastName": "Smith", "slug": "john-smith" },
      "createdAt": "2026-05-06T18:00:00Z",
      "likes": 5,
      "commentCount": 12,
      "isPinned": false,
      "labels": "category-id",
      "url": "https://www.skool.com/your-community/post-slug"
    }
  ],
  "page": 1,
  "total": 86,
  "hasMore": true
}
```

### `posts:filter` — filter posts by criteria

```json
{
  "action": "posts:filter",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "limit": 50,
    "since": "2026-05-01T00:00:00Z",
    "until": "2026-05-06T23:59:59Z",
    "unanswered": true,
    "labelId": "category-id"
  }
}
```

Combine criteria as needed:
- `unanswered: true` — only posts with `commentCount === 0`
- `since` / `until` — date range (ISO strings)
- `labelId` — filter by category

### `posts:get` — get a single post

```json
{
  "action": "posts:get",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "postId": "32-char-hex" }
}
```

### `posts:getComments` — comment tree (fast)

```json
{
  "action": "posts:getComments",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "postId": "32-char-hex" }
}
```

Returns nested replies:

```json
{
  "success": true,
  "comments": [
    {
      "id": "comment-id",
      "content": "Great post!",
      "author": {...},
      "createdAt": "...",
      "replies": [
        { "id": "reply-id", "content": "Thanks!", "replies": [] }
      ]
    }
  ]
}
```

> **Coverage limitation**: Skool's API returns max ~25-30 top-level comments per call. There is no working cursor pagination. If you need more, see [Comment fetching strategies](#comment-fetching-strategies) below.

### Comment fetching strategies

| Method | Speed | Coverage | When to use |
|---|---|---|---|
| `posts:getComments` | ~400ms | ~35 top-level | Quick reads, most posts (free) |
| `posts:getCommentsFull` (Playwright) | ~9-60s | No cap (every reply visible to a human) | When the post has more comments than REST returns. $0.05 scrape-operation event |

Skool's own UI shows max ~58 of 100+ comments. This is a Skool platform limitation, not the actor.

## Write actions

### `posts:create` — create a new post

```json
{
  "action": "posts:create",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "title": "My new post",
    "content": "Plain text body. NO HTML.",
    "labelId": "category-id-if-required",
    "videoIds": []
  }
}
```

> **Plain text only.** Skool does NOT render HTML, markdown, or rich formatting in posts. Tags like `<p>` will appear literally in the rendered post. The only resource that uses TipTap is **course pages** (see [classroom docs](classroom.md)).

If your community **requires categories**, the call fails with `MISSING_CATEGORY` and a `hint`:

```json
{
  "success": false,
  "errorCode": "MISSING_CATEGORY",
  "hint": "This Skool group requires posts to have a category. Pass `params.labelId` (the category id) in posts:create. Get available labels with groups:get."
}
```

Get available labels via `groups:get`. They're in `metadata.label_options`.

### `posts:update` — edit a post or comment

```json
{
  "action": "posts:update",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "postId": "32-char-hex",
    "title": "Updated title (only for posts, ignored for comments)",
    "content": "Updated body"
  }
}
```

Editing a comment is the same call — pass the comment's `id` as `postId`.

### `posts:delete` — delete a post or comment

```json
{
  "action": "posts:delete",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "postId": "32-char-hex" }
}
```

Cascades: deleting a post also deletes all its comments.

### `posts:createComment` — create a comment or nested reply

This is where the post=comment data model matters most.

**Top-level comment** (reply to a post):

```json
{
  "action": "posts:createComment",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "rootId": "POST_ID",
    "parentId": "POST_ID",
    "content": "Welcome! Glad you joined."
  }
}
```

For top-level: **`rootId == parentId == postId`**.

**Nested reply** (reply to another comment):

```json
{
  "params": {
    "rootId": "POST_ID",
    "parentId": "COMMENT_ID",
    "content": "Thanks for sharing!"
  }
}
```

For nested: **`rootId == postId` (always the original post), `parentId == commentId`**.

Both `rootId` and `parentId` are required. The actor will return `INPUT_VALIDATION` if missing.

### `posts:pin` / `posts:unpin` — pin a post to top of feed

```json
{
  "action": "posts:pin",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "postId": "32-char-hex" }
}
```

`unpin` uses an identical shape. These are separate actions — there's no toggle.

### `posts:vote` — like / unlike

```json
{
  "action": "posts:vote",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "postId": "32-char-hex",
    "vote": "up"
  }
}
```

`"vote": "up"` adds a like. `"vote": ""` (empty string) removes it.

## Mentions

You can tag users in posts and comments with this exact syntax:

```
[@Display Name](obj://user/{32-char-hex-userId})
```

The display name can be anything (it's just rendered text). The `userId` is canonical and triggers the in-app notification.

```
Hey [@John Smith](obj://user/cf43939d0edf46378caed98a9d46eadb)! Welcome to the community.
```

Get user IDs from `members:list` or `posts:list` (each post's `author.id`).

## Content format reference

| Resource | Content format | Mentions |
|---|---|---|
| Post body | Plain text | ✅ |
| Comment body | Plain text | ✅ |
| Course page body | TipTap JSON, prefixed `[v2]` | ❌ |

Sending HTML to a post → tags appear literally.
Sending markdown to a post → `**bold**` appears literally with the asterisks.

## Common gotchas

### `posts:update` is `POST`, not `PATCH` or `PUT`

This caught me when reverse-engineering. Skool uses `POST /posts/{id}/update` for edits. Trying `PATCH` or `PUT` returns 405 Method Not Allowed. The actor handles this for you — but if you're calling `api2.skool.com` directly, use `POST`.

### Sort types may not take effect

`sort: "top"` and `sort: "trending"` are passed as params but the SSR endpoint may not honor them. The default `"newest-cm"` (newest by last activity) always works. If you need ranked-by-top, fetch all and sort client-side.

### Editing preserves comments

`posts:update` only changes the title/content. Comments, likes, and pin status stay intact. Safe to edit a post that already has engagement.

### Mentions notify even on edit

If you add a mention in `posts:update`, the mentioned user gets a fresh notification. Useful for adding someone to an old thread; annoying if you're fixing a typo. There's no way to edit silently.

## Pagination patterns

```javascript
// Fetch ALL posts (auto-paginate)
let page = 1;
let allPosts = [];
while (true) {
  const result = await callActor({
    action: 'posts:list',
    cookies, groupSlug,
    params: { page, sort: 'newest-cm' },
  });
  if (!result.success) break;
  allPosts.push(...result.posts);
  if (!result.hasMore) break;
  page++;
}
```

Skool returns ~32 posts per page. A community with 500 posts → 16 actor calls. With Mode B (cookies) at ~2s each, that's ~30 seconds total.

## See also

- [Authentication](authentication.md) — how the cookies you pass actually work
- [Members](members.md) — author IDs come from member listings
- [Classroom](classroom.md) — for rich content (course pages with TipTap)
- [Recipe: Reply to unanswered posts](../recipes/reply-unanswered-posts.md)
