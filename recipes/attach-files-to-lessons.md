---
title: "Attach files to Skool lesson pages (PDFs, ZIPs, sheets)"
description: "Add downloadable resources to your Skool classroom lessons via the API — PDFs, ZIPs, spreadsheets, or external links. Includes the privacy-flag trap that breaks half the integrations."
slug: /recipes/attach-files-to-lessons
type: recipe
funnel: A
section: Recipes
last_updated: 2026-05-28
render_with_liquid: false
---

# Attach files to Skool lesson pages

When you publish a course on Skool, each lesson page can carry downloadable resources — a PDF cheatsheet, a workflow JSON, a spreadsheet template, an external link. The Skool admin UI lets you add these one at a time with a file picker. The API lets you do it programmatically, so you can attach 40 resources across 20 lessons in one script run.

This recipe is the second half of the "ship a course from Markdown" pipeline — once your course tree is built (folders + pages with body), this is how you attach the downloadable assets that turn lessons from "read-only content" into "templates the member can copy and use."

Used in production to attach **23 Google Sheet templates** (the canonical [Cofre del Pirata T-xx pattern](../guide/skool-courses.md)) across 4 courses in [Cágala, Aprende, Repite](https://www.skool.com/cagala-aprende-repite).

## Quick reference (TL;DR for agents)

| | |
|---|---|
| **Goal** | Add file or link resources to a Skool lesson page |
| **Stack** | Any HTTP client + the Apify-hosted actor |
| **Actions used** | [`files:uploadFile`](../docs/files.md#filesuploadfile) → [`classroom:updateResources`](../docs/classroom.md#classroomupdateresources) |
| **Setup time** | ~5 min |
| **Ongoing cost** | `$0.02 × N` resources attached |
| **Key gotcha #1** | Use `files:uploadFile` (privacy: 1), NOT `files:uploadImage` (privacy: 0). Cover-image files are rejected as resources |
| **Key gotcha #2** | Each `updateResources` REPLACES the full array. To add 1 new, send the existing array + the new one |
| **Title limit** | ~34 chars (truncated in UI past that) |

## The privacy-flag trap (read this first)

Skool's `POST /files` accepts a `privacy` flag that determines bucket + ACL. Pick the wrong one and your file is unusable as a resource:

| `privacy` | Bucket | Use case | If you use it as resource |
|---|---|---|---|
| `0` (default) | `sk-groups-dev-files` (public) | Cover images — public URL with `.jpg` suffix | ❌ Rejected: `400 invalid file ... privacy: 0` |
| `1` | `sk-groups-files` (private) | Classroom Resources — signed URL on-demand | ✅ Works |

**You can't fix the privacy flag after upload.** It's set at the original `POST /files` and is not modifiable. If you accidentally uploaded with privacy 0 (e.g. used `files:uploadImage`), re-upload with `files:uploadFile`.

In the actor: `files:uploadImage` always sends `privacy: 0` (for covers), `files:uploadFile` always sends `privacy: 1` (for Resources). Use the right one.

## Prerequisites

- Apify token ([get one](https://console.apify.com/sign-up?fpr=cristian))
- Skool admin cookies for the community (see [Authentication](../docs/authentication.md))
- The `courseId` and `pageId` of the lesson you're attaching to (use [`classroom:getTree`](../docs/classroom.md#classroomgettree) to discover them)
- The file you want to attach (PDF, ZIP, JSON, spreadsheet — any non-executable type)

## Step 1 — Upload the file (with `privacy: 1`)

```json
{
  "action": "files:uploadFile",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "filePath": "/local/path/to/template.pdf",
    "fileName": "template.pdf",
    "contentType": "application/pdf"
  }
}
```

Response:

```json
{
  "success": true,
  "file": {
    "id": "abc123...32hex",
    "file_name": "template.pdf",
    "content_type": "application/pdf"
  }
}
```

Save the `file.id` — you need it in step 2. The file is now in Skool's private bucket. Direct GET to `assets.skool.com/...` returns 403 (correct: signed URLs are issued only when a member clicks Download from the page).

## Step 2 — Attach as a resource

```json
{
  "action": "classroom:updateResources",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "courseId": "course_32hex",
    "pageId": "page_32hex",
    "resources": [
      { "title": "Template (Google Sheet)", "file_id": "abc123..." }
    ]
  }
}
```

The actor handles the underlying call to `PUT /courses/{pageId}` with the canonical body shape (flat, `update_resources: true`, preserves `title`/`desc`/`transcript`/`video_id` via read-then-write).

## Step 3 — Verify the resource appears

```json
{
  "action": "classroom:getTree",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "groupSlug": "your-community" }
}
```

Navigate down to your page and check `metadata.resources` — it's stored as a JSON-encoded string, so `JSON.parse(metadata.resources)` to read it programmatically. You should see your resource with auto-enriched `file_name` and `file_content_type` fields.

## Adding multiple resources or a mix of files and links

The 4 resource types Skool supports (visible in the admin "ADD" button): **file**, **link**, **transcript**, **pin community post**.

For a mix of file + external link in one update:

```json
{
  "action": "classroom:updateResources",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "courseId": "...",
    "pageId": "...",
    "resources": [
      { "title": "PDF Cheatsheet", "file_id": "abc123..." },
      { "title": "Sheet template (copy)", "link": "https://docs.google.com/spreadsheets/d/.../copy" }
    ]
  }
}
```

This is the [Cofre del Pirata pattern](../guide/skool-courses.md): the file is the canonical Markdown wrapper (what/why/how), the link is the Google Sheet "make a copy" URL that the member opens to actually use the template. Both attached to the same lesson page.

## Production gotchas

- **The privacy trap (above).** `files:uploadImage` files are REJECTED as resources. Re-upload with `files:uploadFile`.
- **`update_resources: true` is mandatory.** Without that flag, Skool ignores the new array silently. The actor sends it by default — only relevant if you're calling Skool's API directly.
- **No patch semantics — each call REPLACES.** To add 1 new resource to a page that already has 2, you must send all 3 in the array (existing 2 + new). To clear all resources, send `resources: []`.
- **Title length.** Resource titles get truncated to ~34 chars in the UI. Plan accordingly — "📊 Plantilla Excel · Cash Flow Modelo Founder" reads as "📊 Plantilla Excel · Cash Flow Mo…" in the lesson page.
- **Empty array is valid** — useful for cleanup. `resources: []` + `update_resources: true` removes all attachments from the page.
- **`file_id` cannot be from another community.** Files are scoped to the group where they were uploaded. If you have a multi-community setup, re-upload per community.

## See also

- [Classroom API reference](../docs/classroom.md) — full course / folder / page surface
- [Recipe: Publish a course from Markdown](publish-course-from-markdown.md) — the end-to-end pipeline this fits into
- [Files API reference](../docs/files.md) — the privacy flag explained in depth
- [Cofre del Pirata pattern](../guide/skool-courses.md) — `.md` wrapper + Sheet link template

---

## Use this in production — no setup

The hardest part of building Skool automation isn't the API logic — it's the auth (cookies expire every ~3.5 days, WAF token rotation, weekly Skool buildId changes). The **[Skool All-in-One API actor on Apify](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=attach-files-to-lessons&fpr=cristian)** handles all of that — including the read-then-write that preserves title/desc/video on every `updateResources` call.

- Pay-per-event pricing (~$1.50/mo for typical communities)
- One JSON POST per action — works from any HTTP client
- The `update_resources: true` flag + privacy flag are handled correctly by default

[**→ Open the actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=attach-files-to-lessons&fpr=cristian)

*New to Skool? [Launch your community here](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "HowTo",
  "name": "Attach files to Skool lesson pages",
  "description": "Add downloadable resources (PDFs, ZIPs, sheets, links) to Skool classroom lesson pages via the API. Includes the privacy-flag trap and the array-replacement semantics.",
  "totalTime": "PT5M",
  "tool": [
    {"@type": "HowToTool", "name": "Apify"},
    {"@type": "HowToTool", "name": "Skool admin cookies"}
  ],
  "step": [
    {"@type": "HowToStep", "name": "Upload file with privacy:1", "text": "Use files:uploadFile (NOT files:uploadImage which sets privacy:0 for covers). Save the file.id from the response."},
    {"@type": "HowToStep", "name": "Attach as resource", "text": "Call classroom:updateResources with courseId, pageId, and a resources array. Each call REPLACES the full array — include existing resources to keep them."},
    {"@type": "HowToStep", "name": "Verify with getTree", "text": "Call classroom:getTree and parse metadata.resources (JSON-encoded string) to confirm the attachment is in place."}
  ]
}
</script>
