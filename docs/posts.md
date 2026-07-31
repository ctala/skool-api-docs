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
| `posts:getCommentsFull` | ~5s per 1000 comments | No cap (the entire thread) | When the post has more comments than one REST call returns. $0.05 scrape-operation event |

One call returns ~25-30 top-level comments. The endpoint pages with `created-gt` — a microsecond timestamp echoed back as `last` — and `posts:getCommentsFull` walks it to the end. Verified at 1095/1095 on a 1000-comment thread in about 5 seconds. Because the data comes from the API and not the rendered page, every comment carries a real 32-hex `id` (stable across runs), a real `author.id`, an ISO 8601 `createdAt` and `parentId` threading.

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

#### Optional: email every member, attach a poll, attach an image

```json
{
  "action": "posts:create",
  "params": {
    "title": "Weekly changelog",
    "content": "Everything that shipped this week.",
    "labelId": "category-id",
    "notifyAll": true,
    "pollId": "id-from-posts:createPoll",
    "attachmentId": "id-from-files:uploadImage"
  }
}
```

| Param | What it does |
|---|---|
| `notifyAll` | Emails **every member** of the group — the "Send email to all members" toggle in Skool's composer. Admin only. |
| `pollId` | Attaches a poll created with [`posts:createPoll`](#postscreatepoll--create-a-poll). |
| `attachmentId` | Attaches an image uploaded with [`files:uploadImage`](files.md). A single file id, **not** an array. |

> **`notifyAll` cannot be undone, or added later.** Skool only offers the email at creation time — there is no way to notify members about a post that already exists. Get it right the first time.

> **A `200` does not mean the email was sent.** Skool ignores an unrecognised notify value and returns success anyway. The actor guards this by taking a strict boolean (the string `"true"` is rejected rather than guessed at), but if you're calling `api2.skool.com` directly, know that a typo emails nobody and reports no error. Verify in an inbox: the broadcast email's footer reads *"Don't want admin broadcast emails"*, unlike the usual *"Don't want to be notified when…"*.

> **Broadcasts are rate-limited (~72h per group).** A second one inside the window fails with `notify limit exceeded` — and the rejection is **atomic: the post is not created**. Don't retry assuming the post exists; and don't "fix" it by re-publishing without `notifyAll`, because that post can never be emailed afterwards.

### `posts:createPoll` — create a poll

Polls are their own object, so attaching one takes **two calls**: create the poll, then reference it from the post.

```json
{
  "action": "posts:createPoll",
  "params": { "options": ["Option A", "Option B", "Option C"] }
}
```

```json
{ "pollId": "a0169196540f40f082039657d2b17755" }
```

Then pass that id as `pollId` in `posts:create`.

> **A poll has no title or question field.** Skool's poll is just a list of options — the question lives in the **post's `content`**. If you're wondering where to put "What should we build next?", that's the post body.

Two or more options are required; empty and whitespace-only entries are dropped. Results come back on the post as `pollData` (read-only), with vote counts per option.

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
- [Notifications](notifications.md) — catch mentions/replies pointing at a post
- [Recipe: Reply to unanswered posts](../recipes/reply-unanswered-posts.md)
