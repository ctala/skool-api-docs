---
title: "Generate N Skool lessons from a JSON spec (template system)"
description: "Build a Skool course skeleton from a single JSON spec — drop a {course, folders, pages} object, get a fully wired course tree with bodies and resources. The reusable lesson factory."
slug: /recipes/generate-lessons-from-json
type: recipe
funnel: A
section: Recipes
last_updated: 2026-05-28
render_with_liquid: false
---

# Generate N Skool lessons from a JSON spec

The [Batch launch courses from a spreadsheet](batch-create-courses-spreadsheet.md) recipe assumes you're reading Markdown files from disk. This recipe is the **smaller, faster cousin**: when your lesson content is structured (templated questions, generated copy, AI-drafted bodies), you can skip the file system entirely and drive everything from a JSON spec.

The use case: building 5-10 similar lessons that share structure but vary in content. Onboarding sequences, weekly "what we shipped" updates, AI-generated mini-courses, certifications with N sub-lessons. Write the JSON once, run the script, get the course built.

## Quick reference (TL;DR for agents)

| | |
|---|---|
| **Goal** | Generate N lesson pages from a JSON spec in one script run |
| **Stack** | Any HTTP client + the Apify-hosted actor |
| **Actions used** | [`classroom:createPage`](../docs/classroom.md#classroomcreatepage) → [`classroom:setBody`](../docs/classroom.md#classroomsetbody) (looped) |
| **Setup time** | ~10 min (writing the spec + the loop) |
| **Ongoing cost** | `$0.01 × N` lessons created (~$0.10 for a 10-lesson course) |
| **Best for** | 5-20 similar lessons (>20 → use the spreadsheet pattern) |
| **Key gotcha** | TipTap body MUST start with `[v2]` prefix or it renders as plain text |

## When to use which approach

| Pattern | Best when |
|---|---|
| **[Spreadsheet + Markdown files](batch-create-courses-spreadsheet.md)** | Authoring in your IDE, version control, manual editing per lesson |
| **JSON spec (this recipe)** | Programmatic generation: AI-drafted, templated, weekly recurring |
| **Skool admin UI** | Single one-off lesson — the API isn't worth the setup |

## Prerequisites

- Apify token ([sign up free](https://console.apify.com/sign-up?fpr=cristian))
- Skool admin cookies (see [Authentication](../docs/authentication.md))
- An existing course with a folder ready to receive pages (use [classroom:createCourse + createFolder](batch-create-courses-spreadsheet.md) if you don't have one)

## The spec shape

A flat JSON list of lessons, each with `title`, `body` (TipTap or Markdown→TipTap output), and optional `resources`:

```json
{
  "courseId": "course_32hex",
  "folderId": "folder_32hex",
  "lessons": [
    {
      "title": "L1 — What is automation?",
      "body": "[v2][{\"type\":\"heading\",\"attrs\":{\"level\":1},\"content\":[{\"type\":\"text\",\"text\":\"What is automation?\"}]},{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"text\":\"...body text...\"}]}]"
    },
    {
      "title": "L2 — Your first webhook",
      "body": "[v2]...",
      "resources": [
        { "title": "Workflow JSON", "file_id": "uploaded_file_id" }
      ]
    }
  ]
}
```

## Step 1 — Convert your source to TipTap

If you author in Markdown (or have AI generate Markdown), convert to TipTap JSON before building the spec. Validate nodes against the supported set: `paragraph`, `heading` (attrs.level), `bulletList/listItem`, `orderedList/listItem`, marks `bold` + `link` (attrs.href).

Quick Node converter (using `marked` + a small adapter):

```javascript
import { marked } from 'marked';
import { mdToTiptap } from './md-to-tiptap.js'; // see Markdown→TipTap recipe

function toBody(markdown) {
  const tokens = marked.lexer(markdown);
  const tiptap = mdToTiptap(tokens);
  return '[v2]' + JSON.stringify(tiptap);
}
```

(There's no canonical converter — the [batch-create-courses-spreadsheet](batch-create-courses-spreadsheet.md) recipe has a Python reference impl.)

## Step 2 — Loop: createPage + setBody (+ optional resources)

For each lesson in the spec:

```bash
# Create the page (returns page.id + page.name)
curl -X POST "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=$APIFY_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"action\": \"classroom:createPage\",
    \"cookies\": \"$COOKIES\",
    \"groupSlug\": \"your-community\",
    \"params\": {
      \"courseId\": \"$COURSE_ID\",
      \"folderId\": \"$FOLDER_ID\",
      \"title\": \"$LESSON_TITLE\"
    }
  }"

# Set the body (returns success)
curl -X POST "..." \
  -d "{
    \"action\": \"classroom:setBody\",
    \"cookies\": \"$COOKIES\",
    \"groupSlug\": \"your-community\",
    \"params\": {
      \"pageId\": \"$PAGE_ID\",
      \"body\": \"$TIPTAP_BODY\"
    }
  }"
```

Python loop:

```python
for lesson in spec["lessons"]:
    page = run_action("classroom:createPage", {
        "courseId": spec["courseId"],
        "folderId": spec["folderId"],
        "title": lesson["title"]
    })
    run_action("classroom:setBody", {
        "pageId": page["page"]["id"],
        "body": lesson["body"]
    })
    if "resources" in lesson:
        run_action("classroom:updateResources", {
            "courseId": spec["courseId"],
            "pageId": page["page"]["id"],
            "resources": lesson["resources"]
        })
```

## Step 3 — Verify and capture page URLs

After the loop, fetch `classroom:getTree` and pull the SHORT `name` field for each page — that's the URL slug Skool uses (`?md={name}`), not the 32-hex `id`:

```json
{
  "action": "classroom:getTree",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {}
}
```

Save the URLs to share with members:

```
https://www.skool.com/your-community/classroom/{course.name}?md={page.name}
```

## Production gotchas

- **The `[v2]` prefix is non-negotiable.** Without it, your body renders as plain text including the JSON itself — looks broken to members. The actor doesn't add it for you on `setBody` because some callers want raw text. Always prefix programmatically.
- **TipTap node validation.** Skool rejects unknown nodes silently — the page renders without them. Stick to the validated set above. If you have markdown with images, tables, code blocks: convert images to upload-then-link, tables to lists, code blocks to `<pre>`-styled paragraphs.
- **Rate limit on writes.** Skool's ceiling is ~25 writes/min. The actor serializes internally. If you're building 50+ lessons in one run, expect ~2 minutes of wall time.
- **Folder must exist before pages.** `createPage` with a non-existent `folderId` returns 400. If your spec lists a new folder, create it first with `classroom:createFolder`.
- **`page.name` is generated by Skool from the title.** Two pages with identical titles get suffixes (`-2`, `-3`). If you need predictable URLs, ensure unique titles in your spec.

## When you've outgrown this pattern

If your spec exceeds ~20 lessons or includes covers/folders/multi-course logic, switch to the [Batch launch courses from a spreadsheet](batch-create-courses-spreadsheet.md) pipeline — it handles the upload-cover + create-course + multi-folder orchestration this recipe deliberately skips.

## See also

- [Recipe: Batch launch courses from a spreadsheet](batch-create-courses-spreadsheet.md) — when your spec grows
- [Recipe: Publish a course from Markdown](publish-course-from-markdown.md) — single-course version of the spreadsheet pattern
- [Recipe: Attach files to lesson pages](attach-files-to-lessons.md) — the resources step in detail
- [Classroom API reference](../docs/classroom.md) — every action with params

---

## Use this in production — no setup

The hardest part of building Skool automation isn't the API logic — it's the auth (cookies expire every ~3.5 days, WAF token rotation, weekly Skool buildId changes). The **[Skool All-in-One API actor on Apify](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=generate-lessons-from-json&fpr=cristian)** handles all of that.

- Pay-per-event pricing (~$1.50/mo for typical communities)
- The classroom action set is the most production-tested part of the actor — 1,200+ page writes in the wild
- The `[v2]` prefix, page-name generation, and folder validation are all surfaced clearly via the action params

[**→ Open the actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=generate-lessons-from-json&fpr=cristian)

*New to Skool? [Launch your community here](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "HowTo",
  "name": "Generate N Skool lessons from a JSON spec",
  "description": "Build a Skool course skeleton from a single JSON spec. Best for 5-20 similar lessons or AI-generated content where the spreadsheet+Markdown pattern is overkill.",
  "totalTime": "PT10M",
  "tool": [{"@type": "HowToTool", "name": "Apify"}, {"@type": "HowToTool", "name": "Python or Node script"}, {"@type": "HowToTool", "name": "Skool admin cookies"}],
  "step": [
    {"@type": "HowToStep", "name": "Convert source to TipTap", "text": "Convert Markdown / AI-generated content to TipTap JSON with [v2] prefix. Validate nodes against the supported Skool subset."},
    {"@type": "HowToStep", "name": "Loop createPage + setBody", "text": "For each lesson in the spec: call classroom:createPage to get a page.id, then classroom:setBody with the [v2]-prefixed body. Optionally classroom:updateResources for attachments."},
    {"@type": "HowToStep", "name": "Verify and capture URLs", "text": "Call classroom:getTree to pull the SHORT name field for each page (the URL slug Skool uses for ?md={name}). Save the URLs to share with members."}
  ]
}
</script>
