---
title: "Batch launch Skool courses from a spreadsheet (covers + folders + lessons)"
description: "Spin up multiple Skool courses in one script: read a spreadsheet, upload covers, create the course tree (course → folders → lessons), publish Markdown bodies. End-to-end automation."
slug: /recipes/batch-create-courses-spreadsheet
type: recipe
funnel: A
section: Recipes
last_updated: 2026-05-28
render_with_liquid: false
---

# Batch launch Skool courses from a spreadsheet

Manually creating courses in the Skool admin UI is slow: upload cover, type title + description, create folders, create pages one by one, paste each lesson body, attach resources. For a single 18-lesson course that's ~2 hours of clicking. For 5 courses, you lose a day.

The API makes it a script. This recipe is the **end-to-end course launch pipeline** — read a spreadsheet listing your courses + lessons, upload each cover, build the course tree (course → folders → pages), publish each lesson body as TipTap JSON, attach resources. One script run, repeatable, no clicks.

It's how [Cágala, Aprende, Repite](https://www.skool.com/cagala-aprende-repite) shipped its current **23-course classroom** — every course built from a Markdown source tree via this pattern.

## Quick reference (TL;DR for agents)

| | |
|---|---|
| **Goal** | Build a multi-course classroom from a structured source (spreadsheet + Markdown files) |
| **Stack** | Python or Node script + the Apify-hosted actor |
| **Actions used** | [`files:uploadImage`](../docs/files.md#filesuploadimage) → [`classroom:createCourse`](../docs/classroom.md#classroomcreatecourse) → [`classroom:createFolder`](../docs/classroom.md#classroomcreatefolder) → [`classroom:createPage`](../docs/classroom.md#classroomcreatepage) → [`classroom:setBody`](../docs/classroom.md#classroomsetbody) → [`classroom:updateResources`](../docs/classroom.md#classroomupdateresources) |
| **Setup time** | ~30 min first time (writing the script) |
| **Ongoing cost** | ~`$0.05` per course (regardless of lesson count) |
| **Production tested** | 18-course classroom built this way, ~1,200 page writes total |
| **Smoke-test gate** | Build in a throwaway group first (R-RELEASE rule), then run in production |

## The shape of your input

A spreadsheet (or YAML / CSV — whatever's easiest) with one row per course:

| course_id | title | description | cover_path | tier (0/2/3) | structure |
|---|---|---|---|---|---|
| `mc-01` | Tu Primer Empleado de IA | Build your first AI agent... | `./covers/mc-01.jpg` | 2 | `M1/L1.md, M1/L2.md, M2/L1.md` |
| `mc-02` | LinkedIn para founders | Convert your network... | `./covers/mc-02.jpg` | 2 | `M1/L1.md, M1/L2.md, M2/L1.md, M2/L2.md` |
| ... |

Plus a directory tree:

```
courses/
  mc-01/
    M1/
      L1.md
      L2.md
    M2/
      L1.md
  mc-02/
    ...
covers/
  mc-01.jpg
  mc-02.jpg
```

Each `Lx.md` is the lesson body in Markdown — your authoring source of truth. The script converts Markdown → TipTap JSON for Skool.

## The 6-step pipeline (per course)

For each row in your spreadsheet:

### Step 1 — Upload the cover (`files:uploadImage`)

```json
{
  "action": "files:uploadImage",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "filePath": "./covers/mc-01.jpg",
    "fileName": "mc-01-cover.jpg"
  }
}
```

Returns `{file: {id, read_url}}`. You need both — `read_url` for the cover URL Skool stores, `id` for the file reference. Recommended cover dimension: 1460×752.

### Step 2 — Create the course (`classroom:createCourse`)

```json
{
  "action": "classroom:createCourse",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "title": "Tu Primer Empleado de IA",
    "description": "Build your first AI agent that runs autonomously...",
    "coverImageUrl": "https://...cover_read_url...jpg",
    "coverFileId": "file_id_from_step_1",
    "privacy": 2,
    "minTier": 2
  }
}
```

Returns `{course: {id}}`. Save it — every folder and page below references this `courseId`.

**Privacy values:** `0` (Open) / `1` (Level unlock) / `2` (Private/Premium) / `3` (Buy now) / `4` (Time unlock with drip). See [tier mapping](../docs/classroom.md#tier-mapping).

### Step 3 — Create the folders (`classroom:createFolder`)

For each top-level module (`M1`, `M2`, ...):

```json
{
  "action": "classroom:createFolder",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "courseId": "course_id_from_step_2",
    "title": "Módulo 1 — Setup"
  }
}
```

Returns `{folder: {id}}`. Each lesson page goes inside a folder.

### Step 4 — Create the pages (`classroom:createPage`)

For each `Lx.md` inside the module:

```json
{
  "action": "classroom:createPage",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "courseId": "course_id",
    "folderId": "folder_id_from_step_3",
    "title": "L1.1 — Tu primer agente en 10 minutos"
  }
}
```

Returns `{page: {id, name}}`. The `name` is the SHORT id — that's what Skool uses in the URL (`?md={name}`), NOT the 32-hex `id`. Both are useful: `id` for write calls, `name` for sharing links.

### Step 5 — Publish the body (`classroom:setBody`)

Convert the lesson's Markdown to TipTap JSON (validate nodes: `paragraph`, `heading`, `bulletList/listItem`, marks `bold` + `link`), then:

```json
{
  "action": "classroom:setBody",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "pageId": "page_id_from_step_4",
    "body": "[v2][{\"type\":\"heading\",\"attrs\":{\"level\":1},\"content\":[{\"type\":\"text\",\"text\":\"...\"}]},...]"
  }
}
```

**Critical:** the body string MUST start with the literal prefix `[v2]` followed by the JSON array (no separator). Without `[v2]`, Skool renders it as plain text. The actor enforces this.

### Step 6 (optional) — Attach resources (`classroom:updateResources`)

If the lesson has downloadable assets (PDF, sheet, JSON workflow), add them:

```json
{
  "action": "classroom:updateResources",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "courseId": "course_id",
    "pageId": "page_id",
    "resources": [
      { "title": "Workflow JSON", "file_id": "uploaded_workflow_id" },
      { "title": "Sheet template", "link": "https://docs.google.com/.../copy" }
    ]
  }
}
```

See [Attach files to lessons](attach-files-to-lessons.md) for the privacy-flag trap (use `files:uploadFile` for resource files, NOT `files:uploadImage`).

## The R-RELEASE rule: smoke test in a throwaway group FIRST

**Never build directly in your production community.** The course tree is created with real IDs, and reversing it means deleting courses (which Skool surfaces in member notifications even after delete in some edge cases).

The release pattern used in production:

```bash
# 1. Run the script against a throwaway group
GROUP_SLUG=nyx-trial-run-8420 node build-course.mjs

# 2. Manually verify in the throwaway group's classroom
# (cover, structure, body rendering, resources, privacy correct)

# 3. Once approved, run in production
GROUP_SLUG=cagala-aprende-repite node build-course.mjs

# 4. Clean up the throwaway group's smoke-test course
```

This single rule has caught: typos in titles, wrong tier mapping (free vs Premium), cover not rendering due to bad dimensions, lesson order off because folder created after page, body Markdown→TipTap conversion losing a heading level. All cheaper to find in the throwaway group than to fix in production.

## Production gotchas

- **Cover URL needs `.jpg` suffix even if uploaded as PNG.** Skool converts PNG/WebP → JPG server-side, but the stored URL has `.jpg` regardless. Use the response `read_url` directly — don't reconstruct.
- **Course `state: 2` = published.** The `state` field is NOT updatable via API after creation. To unpublish (convert to draft), you must toggle in the Skool admin UI. Plan your `state` correctly at creation time.
- **Classroom URLs use the SHORT id (`name`), NOT the 32-hex `id`.** Course URL: `/community/classroom/{course.name}`. Lesson URL: `/community/classroom/{course.name}?md={page.name}`. Confusing the two gives 404s. Both come back in `classroom:getTree`.
- **Markdown internal cross-links (`[Next lesson](./L2.md)`) break in Skool.** Sanitize to plain text or absolute URLs before `setBody`. The converter strips relative `.md` links.
- **Default new course: `privacy=1, min_tier=2`** (Premium tier in CAR mapping). Set explicitly if you want different defaults.
- **PUT with `{metadata: {...}}` wrapper RESETS `privacy` to 0 silently.** Use the actor's `classroom:updateCourse` which does read-then-write to preserve `privacy`/`min_tier`/`amount`. See [classroom API gotchas](../docs/classroom.md#gotchas).
- **Verify Google Sheet links are `anyone:reader`.** If you attach a Sheet as a resource link and forget to set permissions, members get a "request access" page instead of the template.

## See also

- [Classroom API reference](../docs/classroom.md) — full course / folder / page surface + tier mapping
- [Recipe: Publish a course from Markdown](publish-course-from-markdown.md) — single-course version of this pipeline
- [Recipe: Attach files to lessons](attach-files-to-lessons.md) — the resource step in detail (privacy-flag trap)
- [Files API reference](../docs/files.md) — uploadImage vs uploadFile

---

## Use this in production — no setup

The hardest part of building Skool automation isn't the API logic — it's the auth (cookies expire every ~3.5 days, WAF token rotation, weekly Skool buildId changes). The **[Skool All-in-One API actor on Apify](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=batch-create-courses-spreadsheet&fpr=cristian)** handles all of that — including the 6-action pipeline wrapped behind a consistent JSON-over-HTTP surface.

- Pay-per-event pricing (~$1.50/mo for typical communities)
- The classroom action set is the most production-tested part of the actor — 1,200+ page writes in the wild
- Cover upload + privacy + `[v2]` prefix are all handled correctly by default

[**→ Open the actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=batch-create-courses-spreadsheet&fpr=cristian)

*New to Skool? [Launch your community here](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "HowTo",
  "name": "Batch launch Skool courses from a spreadsheet",
  "description": "End-to-end pipeline to spin up multiple Skool courses from a structured source — read a spreadsheet, upload covers, build course tree (course → folders → pages), publish Markdown bodies as TipTap, attach resources.",
  "totalTime": "PT30M",
  "tool": [
    {"@type": "HowToTool", "name": "Apify"},
    {"@type": "HowToTool", "name": "Python or Node script"},
    {"@type": "HowToTool", "name": "Skool admin cookies"}
  ],
  "step": [
    {"@type": "HowToStep", "name": "Upload cover", "text": "Call files:uploadImage with the cover JPG. Save the file.id and read_url."},
    {"@type": "HowToStep", "name": "Create course", "text": "Call classroom:createCourse with title, description, coverImageUrl, coverFileId, privacy, minTier."},
    {"@type": "HowToStep", "name": "Create folders", "text": "For each module, call classroom:createFolder with courseId and title."},
    {"@type": "HowToStep", "name": "Create pages", "text": "For each lesson, call classroom:createPage with courseId, folderId, title. Save the SHORT name for sharing URLs."},
    {"@type": "HowToStep", "name": "Publish body", "text": "Convert lesson Markdown to TipTap JSON, prefix with [v2], call classroom:setBody."},
    {"@type": "HowToStep", "name": "Attach resources", "text": "Optionally call classroom:updateResources with file_id (privacy:1) or external links."}
  ]
}
</script>
