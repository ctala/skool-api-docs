# Actions Reference

Every action the Skool All-in-One API actor supports. Use this as a quick lookup; for examples and gotchas, follow the link to the detailed doc.

All actions use the same shape:

```json
{
  "action": "<namespace:operation>",
  "cookies": "auth_token=...; client_id=...; aws-waf-token=...",
  "groupSlug": "your-community",
  "params": { /* per-action */ }
}
```

(or `email + password` instead of `cookies` — see [authentication](authentication.md))

## System

| Action | Params | Description |
|---|---|---|
| `system:health` | — | Healthcheck. No auth, no Skool calls. Returns `{ok, version, node, timestamp}`. Used as the input schema's default action so Apify's daily quality check always passes |
| `system:debug` | `cookies`, `groupSlug` | SSR diagnostics: returns Skool homepage status + `buildId` extracted + SSR fetch result + REST client probe. Useful for debugging when something doesn't work (added in 0.3.25) |

## Auth

| Action | Params | Description |
|---|---|---|
| `auth:login` | `email`, `password`, `groupSlug` | Login via headless Playwright (~10s). Returns cookies + buildId valid ~3.5 days. [→ Authentication](authentication.md) |

## Posts & Comments

> Skool's posts and comments are the same object. See [Posts & Comments](posts.md) for the data model.

| Action | Params | Description |
|---|---|---|
| `posts:list` | `page?`, `sort?`, `limit?` | Single page of posts |
| `posts:filter` | `since?`, `until?`, `unanswered?`, `labelId?`, `limit?` | Filter posts by criteria (combine any) |
| `posts:get` | `postId` | Single post by ID |
| `posts:create` | `title`, `content`, `labelId?`, `videoIds?` | Create a post (plain text content) |
| `posts:update` | `postId`, `title?`, `content?` | Edit a post or comment |
| `posts:delete` | `postId` | Delete a post or comment (cascades) |
| `posts:pin` | `postId` | Pin to top of feed |
| `posts:unpin` | `postId` | Remove pin |
| `posts:vote` | `postId`, `vote: "up" \| ""` | Like / unlike |
| `posts:getComments` | `postId` | Comment tree via REST (~2s, max ~35 top-level). Free read |
| `posts:getCommentsFull` | `postId` OR `postSlug` | **Full thread coverage** via Playwright DOM scroll (~30-60s, no cap). $0.05 scrape-operation event. Use when `posts:getComments` truncates and you need every reply. Added in 0.3.24 |
| `posts:createComment` | `rootId`, `parentId`, `content` | Create comment or nested reply. For top-level: `rootId == parentId == postId`. For nested: `parentId == commentId` |

[→ Posts & Comments docs](posts.md)

## Members

| Action | Params | Description |
|---|---|---|
| `members:list` | `page?`, `limit?` | Active members with role + tier info |
| `members:pending` | `limit?` | Members awaiting approval |
| `members:approve` | `memberId` | Approve pending applicant |
| `members:reject` | `memberId` | Reject pending applicant |
| `members:ban` | `memberId` | Ban active member |
| `members:batchApprove` | `memberIds: string[]` | Approve N members; per-item results |

[→ Members docs](members.md)

## Events (calendar)

> Calendar events live independently of posts. Useful for community calls, workshops, and live sessions. Added in 0.3.24.

| Action | Params | Description |
|---|---|---|
| `events:list` | `page?`, `limit?` | All calendar events for the group (past + future). Returns occurrence list with `nextOccurrence`, `timezone`, `occurrenceId` |
| `events:upcoming` | `limit?` | Only future events sorted ascending. Convenience wrapper for "what's coming up" use cases |

## Classroom (courses, folders, pages)

> Skool's classroom UI renders 3 levels: **Course** → **Page direct** OR **Folder** → **Page**. See [Classroom](classroom.md) for the data model.

| Action | Params | Description |
|---|---|---|
| `classroom:listCourses` | — | Top-level courses for the group |
| `classroom:getTree` | `courseId` | Recursive tree (folders + pages) for a course |
| `classroom:createCourse` | `title`, `desc?`, `coverImage?`, `coverImageFile?`, `privacy?` (0-4), `minTier?`, `amount?`, `drip?`, `state?`, `affiliateCommissionEligible?` | Create top-level course tile |
| `classroom:createFolder` | `parentCourseId`, `title`, `state?` | Create folder (`unit_type:"set"`) |
| `classroom:createPage` | `courseId`, `parentId`, `title`, `state?` | Create page (`unit_type:"module"`). `parentId` is the course id (top-level page) or folder id (nested) |
| `classroom:setBody` | `pageId`, `title`, `bodyMarkdown?` OR `bodyRaw?`, `videoId?`, `transcript?` | Set page body. `bodyMarkdown` is auto-converted to TipTap |
| `classroom:updateCourse` | `courseId`, `title?`, `desc?`, `coverImage?`, `coverImageFile?`, `privacy?`, `minTier?`, `amount?`, `transcript?`, `videoId?` | Read-then-write update. Any field you don't pass is preserved (avoids the silent privacy-reset bug) |
| `classroom:deleteUnit` | `id` | Delete course/folder/page (cascades) |
| `classroom:updateResources` | `pageId`, `fileIds: string[]` | Replace the Resources attached to a lesson page. Each `fileId` must come from a prior `files:uploadFile` call. Passing `[]` detaches all resources |

[→ Classroom docs](classroom.md)

## Files

| Action | Params | Description |
|---|---|---|
| `files:uploadImage` | `bufferBase64` OR `imageUrl` | Upload a **cover image**; returns `{coverImageUrl, coverImageFile}` ready for `classroom:createCourse` / `classroom:updateCourse` |
| `files:uploadFile` | `bufferBase64` OR `fileUrl`, `filename` | Upload a **private file** (PDF, JSON, ZIP, anything) for classroom Resources. Returns `{fileId}` to pass to `classroom:updateResources` |

[→ Files docs](files.md)

## Groups

| Action | Params | Description |
|---|---|---|
| `groups:get` | `slug` | Group metadata (description, tier definitions, label_options, logo URLs) |
| `groups:setAutoDM` | `message` | Update Auto DM message for new members. Plain text + `#NAME#` + `#GROUPNAME#` tokens. 300-char limit |

[→ Groups docs](groups.md)

## privacy values (for courses)

| Value | Meaning |
|---|---|
| `0` | **Open** — anyone with group access |
| `1` | **Level unlock** — uses `minTier` as gamification level (1-9) or paid tier override |
| `2` | **Private** — invite-only |
| `3` | **Buy now** — paid course; requires `amount` (USD cents); may also use `minTier` as paid tier override |
| `4` | **Time unlock** — drip released over time; requires `drip: { enabled: true, days: N }` |

## Title length constraints

Skool enforces a **50-character maximum** on:
- Course titles
- Folder (set) titles
- Page (lesson) titles

Emojis count as 2 chars in UTF-16. The actor returns `TITLE_TOO_LONG` with a hint if you exceed.

## See also

- [Authentication](authentication.md) — `auth:login` flow + cookie handling
- [Error handling](error-handling.md) — full `errorCode` catalog
- [AI agents](agents.md) — function calling specs, MCP integration, Claude Skill
- [Recipes](../README.md#recipes) — full integrations
