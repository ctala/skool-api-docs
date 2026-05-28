# Classroom

Build entire Skool courses programmatically. Markdown in, fully-rendered classroom out — with covers, folders, lessons, tier gating, drip, and the works.

This is the most powerful resource the actor exposes — and the one that took the most reverse-engineering. There are gotchas. Read them first.

## Data model

Skool's classroom UI renders **3 visible levels**:

```
Course (top-level tile, visible in /classroom)
├── Page (lesson, direct child of course)
└── Folder
    ├── Page (lesson)
    └── Page (lesson)
```

Internally Skool calls these:

| UI term | `unit_type` | Notes |
|---|---|---|
| Course | `"course"` | Top-level tile. No `parentId`. |
| Folder | `"set"` | Container. `parentId` = course id. |
| Page (lesson) | `"module"` | Leaf. `parentId` = course id (direct) or set id (nested in folder). |

**Modules nested inside other modules are invisible in the UI** even if you create them. Don't try to nest pages inside pages — Skool ignores them visually.

## Actions

### `classroom:listCourses`

```json
{ "action": "classroom:listCourses", "cookies": "...", "groupSlug": "..." }
```

Returns top-level courses for the group with `id`, `metadata.title`, `metadata.privacy`, `metadata.min_tier`, etc.

### `classroom:getTree`

```json
{
  "action": "classroom:getTree",
  "cookies": "...",
  "groupSlug": "...",
  "params": { "courseId": "32-char-hex" }
}
```

Returns the full recursive tree of a course: course → folders → pages. Use this to discover IDs before doing batch updates.

### `classroom:createCourse`

```json
{
  "action": "classroom:createCourse",
  "cookies": "...",
  "groupSlug": "...",
  "params": {
    "title": "🤖 My New Course",
    "desc": "Plain-text description shown on the tile (~500 chars max).",
    "coverImage": "https://assets.skool.com/f/.../...jpg",
    "coverImageFile": "32-char-hex-from-files-uploadImage",
    "privacy": 1,
    "minTier": 2,
    "state": 2,
    "affiliateCommissionEligible": true
  }
}
```

| Param | Required | Description |
|---|---|---|
| `title` | ✅ | ≤50 chars (UTF-16; emojis count as 2) |
| `desc` | optional | Plain text shown on tile; ~500 chars before truncation |
| `coverImage` + `coverImageFile` | optional but paired | Get both from `files:uploadImage` |
| `privacy` | optional | `0` Open · `1` Level unlock · `2` Private · `3` Buy now · `4` Time unlock |
| `minTier` | optional | Gamification level OR paid tier override |
| `amount` | optional | Required when `privacy=3`. USD cents (`14700` = $147) |
| `drip` | optional | Required when `privacy=4`. `{ enabled: true, days: 5 }` |
| `state` | optional | `1` draft · `2` active (default `2`) |
| `affiliateCommissionEligible` | optional | If group has affiliate program enabled |

### `classroom:createFolder` (set)

```json
{
  "action": "classroom:createFolder",
  "cookies": "...",
  "groupSlug": "...",
  "params": {
    "parentCourseId": "course-id-32hex",
    "title": "🧠 Module 1: The Brain"
  }
}
```

### `classroom:createPage` (module)

```json
{
  "action": "classroom:createPage",
  "cookies": "...",
  "groupSlug": "...",
  "params": {
    "courseId": "course-id-32hex",
    "parentId": "course-id-32hex OR folder-id-32hex",
    "title": "🚀 Lesson 1.1: Getting Started"
  }
}
```

`parentId` = course id for direct lesson, folder id for nested lesson.

### `classroom:setBody` — set page content

```json
{
  "action": "classroom:setBody",
  "cookies": "...",
  "groupSlug": "...",
  "params": {
    "pageId": "page-id-32hex",
    "title": "🚀 Lesson 1.1: Getting Started",
    "bodyMarkdown": "## Welcome\n\nThis is **bold**.\n\n- Item one\n- Item two\n\n> A callout block.",
    "videoId": "",
    "transcript": null
  }
}
```

The actor converts `bodyMarkdown` to Skool's TipTap JSON automatically. Pass `bodyRaw` instead if you've already produced the `[v2]<JSON>` literal yourself.

### `classroom:updateCourse` — safe update (read-then-write)

```json
{
  "action": "classroom:updateCourse",
  "cookies": "...",
  "groupSlug": "...",
  "params": {
    "courseId": "course-id-32hex",
    "coverImage": "https://...",
    "coverImageFile": "..."
  }
}
```

This is the action you use for **any** edit to a course (cover, title, description, privacy, tier). It internally fetches the course's current state, merges your changes on top, and writes the full body. Any field you don't pass is preserved.

This costs +1 GET (~200ms) per update. **Worth it** — see "R-PUT-COURSE" below.

### `classroom:updateResources` — attach files or links to a lesson page

Add downloadable resources to a classroom page — PDFs, ZIPs, sheets (via `file_id` from [`files:uploadFile`](files.md#filesuploadfile)) or external links (e.g. Google Sheets "make a copy" URLs).

```json
{
  "action": "classroom:updateResources",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "courseId": "course_32hex",
    "pageId": "page_32hex",
    "resources": [
      { "title": "PDF Cheatsheet", "file_id": "abc123..." },
      { "title": "Sheet template (copy)", "link": "https://docs.google.com/spreadsheets/d/.../copy" }
    ]
  }
}
```

Resources support 4 types (mirrors the admin UI "ADD" button): **file**, **link**, **transcript**, **pin community post**. The actor accepts `file_id` and `link` shapes today; `transcript` and `pin community post` shapes pending wrapping.

#### Critical rules (each one is a real production gotcha)

- **No patch semantics — each call REPLACES the full array.** To add 1 new resource to a page with 2 existing, send all 3 in the array. To clear all resources, send `resources: []`.
- **`file_id` must come from `files:uploadFile` (`privacy: 1`)**, NOT `files:uploadImage` (`privacy: 0`). Cover-image files are rejected: `400 invalid file ... privacy: 0`.
- **`update_resources: true` is mandatory** on the underlying PUT. The actor sends it by default — only relevant if you're calling Skool's REST API directly without the wrapper.
- **Title gets truncated to ~34 chars in the UI.** Plan titles accordingly.
- **`file_id` is scoped to its origin group.** A file uploaded to group A can't be used as a resource in group B's classroom. Re-upload per community.

When reading from `metadata.resources` (returned by `classroom:getTree`), note that the field is stored as a **JSON-encoded string** — `JSON.parse` it before iterating. Skool auto-enriches file resources with `file_name` and `file_content_type` on read.

See the full recipe: [Attach files to lesson pages](../recipes/attach-files-to-lessons.md).

### `classroom:deleteUnit`

```json
{
  "action": "classroom:deleteUnit",
  "cookies": "...",
  "groupSlug": "...",
  "params": { "id": "course-or-folder-or-page-id" }
}
```

Cascades: deleting a course also deletes its folders and pages.

## Markdown → TipTap converter

The actor includes a zero-dependency converter that turns markdown into Skool's TipTap JSON format. Supported syntax:

| Markdown | TipTap result |
|---|---|
| `## H2` / `### H3` | `heading` (level 2/3). H1 is stripped — Skool puts the title above the body. H4+ demoted to H3. |
| `**bold**` | `text` with `bold` mark |
| `*italic*` | `text` with `italic` mark |
| `` `code` `` | `text` with `code` mark |
| `[link](url)` | `text` with `link` mark and `attrs.href` |
| `` ```fenced``` `` | `codeBlock` |
| `- bullet` / `1. ordered` | `bulletList` / `orderedList` with `listItem` children |
| `> quote` | `blockquote`. Lists nested inside flatten to paragraphs prefixed with `• ` (Skool only renders the border on `paragraph` children) |
| Tables ≤5 cols × ≤10 rows × ≤30 chars/cell | `codeBlock` with monospace alignment |
| Tables larger | `bulletList` with bold-key prefixes |
| Blank lines | Block delimiters (NOT empty paragraphs — TipTap handles spacing via CSS) |

Convention `click` → `clic` is auto-applied (LATAM Spanish convention). Strip with a pre-processor if you don't want it.

## R-PUT-COURSE — the silent privacy reset bug

> **The most important gotcha in this entire actor.**

If you call `PUT /courses/{courseId}` directly to `api2.skool.com` with a partial body — even just `{cover_image, cover_image_file}` — Skool **silently resets `privacy` to 0 (Open)**. Your premium course becomes public. No error, no warning.

Confirmed empirically against 12 production courses on May 6, 2026. `min_tier` is preserved (Skool default = 0 = "no tier requirement"), but `privacy` and `amount` are not.

**The actor handles this for you** via `classroom:updateCourse`'s read-then-write pattern. As long as you use that action, your fields stay safe.

**If you call the API directly**: always include `privacy` and `min_tier` in every PUT body, even when "just" updating the cover.

## Cover image upload flow

Course covers are 1460×752 JPEG. Upload them with `files:uploadImage`, then pass the returned `coverImageUrl` + `coverImageFile` to `createCourse` / `updateCourse`.

```json
// 1. Upload
{ "action": "files:uploadImage", "cookies": "...", "groupSlug": "...",
  "params": { "bufferBase64": "<base64-encoded JPEG>" } }
// returns: { coverImageUrl, coverImageFile }

// 2. Use in course creation
{ "action": "classroom:createCourse", ...,
  "params": {
    "title": "...",
    "coverImage": "https://assets.skool.com/...",
    "coverImageFile": "32-char-hex"
  } }
```

Skool re-encodes server-side (PNG/WebP → JPG). External URLs are rejected.

## Tier conventions

Tier semantics depend on each community's `groups:get` definitions, but a common convention (used in CAR):

| `min_tier` | Convention |
|---|---|
| `0` | Standard / Free — no restriction |
| `2` | Premium — first paid tier |
| `3` | VIP — second paid tier |

`privacy: 1` (Level unlock) uses `min_tier` as the threshold. So `{privacy: 1, min_tier: 2}` = "course visible to Premium and above."

## Common gotchas

### Title too long

Skool's 50-char limit applies to **all** classroom titles (course, folder, page). Emojis count as 2 chars in UTF-16. The actor returns `TITLE_TOO_LONG` with a hint if you exceed. Validate before you create.

### Re-creating a deleted course

Course `id` and slug (`name` field) don't reuse. Delete + recreate gives you a brand new course with a different URL.

### `coverImage` without `coverImageFile`

Skool wants both. The URL is the read path; the file id is the storage reference. They're paired — don't pass one without the other.

### Pages can have video too

`classroom:setBody` accepts `videoId` (Skool's internal video ID, not a YouTube URL). Resolving YouTube URL → Skool video ID is **not yet exposed** by the actor; for now, paste the URL into the Skool UI and let it resolve, then read the page's `metadata.video_id`.

### Drip + `state: 1` (draft)

Pages set to `state: 1` (draft) are invisible to non-admin members regardless of `privacy` and `drip` config. Useful for staging content before launch.

## Recipes

- [**Publish a course from markdown files**](../recipes/publish-course-from-markdown.md) — full pipeline: directory tree → Skool course
- [**Batch update course covers**](../recipes/batch-update-course-covers.md) — refresh visual identity across N courses safely

## See also

- [Files](files.md) — image upload flow
- [Groups](groups.md) — affiliate / tier configuration
