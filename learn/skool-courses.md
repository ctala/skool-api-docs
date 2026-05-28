---
title: "Skool Courses — How the Classroom Works (2026)"
description: "Skool courses live in the classroom. Each course = folders + pages with rich content. Drip, gating, tier access. How to create, publish, and automate."
slug: /learn/skool-courses
type: glossary
primary_keyword: "skool courses"
search_volume_monthly: 90
funnel: B
playbook: glossary
last_updated: 2026-05-19
canonical: https://ctala.github.io/skool-api-docs/learn/skool-courses/
---


> **TL;DR.** Skool's "classroom" hosts unlimited courses, included in the flat $99/mo. Each course is a tree of folders and pages. Pages have rich content (text, video, attachments). You can gate access by member tier OR by gamification level. Markdown auto-converts to Skool's internal format via the [API](../integrations/skool-python.md). No assignments or quizzes — for that use Kajabi/Thinkific.

## What a Skool course is

A **course** is the top-level container. Inside a course you have:

- **Folders** — group related pages (e.g. "Module 1: Foundations")
- **Pages** — the actual lesson content

Each page can contain:

- Rich text (headings, bold, italic, lists, code blocks, quotes)
- Video embeds (YouTube, Vimeo, Loom)
- Image attachments
- Downloadable files (PDFs, audio, anything)
- Inline links

There are no native quizzes, assignments, completion tests, or graded items. If your course needs those, Skool isn't the platform — Kajabi or Thinkific are LMS-first.

## Access control

Each course has:

- **Privacy** — public (anyone in the community), private (specific tier only)
- **Min tier** — gate the course to a specific paid tier
- **Min level** (gamification) — unlock the course when a member reaches level N
- **Drip** — release pages on a schedule (e.g. page 1 on day 0, page 2 on day 7)

This is how you build paid course tiers, gamified unlocks, and time-released curricula.

## Creating a course — UI

1. Go to your community → Classroom
2. Click "Create course"
3. Set title (≤50 chars), description, cover image
4. Add folders + pages
5. For each page, write content in the rich editor
6. Set privacy/tier/level/drip per page

Time to MVP: ~30-60 minutes for a 5-page course with text + 1 video per page.

## Creating a course — API (programmatic)

If you have course content in markdown files (Git-tracked notes, Notion exports, etc.), the [Skool API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=glossary&utm_campaign=skool-courses&fpr=cristian) publishes it all at once:

```bash
# 1. Create the course
curl -X POST "..." -d '{
  "action": "classroom:createCourse",
  "params": {"title": "Foundations", "desc": "...", "privacy": 1, "minTier": 1}
}'

# 2. Create folders inside
curl -X POST "..." -d '{
  "action": "classroom:createFolder",
  "params": {"parentCourseId": "...", "title": "Module 1"}
}'

# 3. Create pages
curl -X POST "..." -d '{
  "action": "classroom:createPage",
  "params": {"courseId": "...", "parentId": "...", "title": "Lesson 1"}
}'

# 4. Set page body (markdown → auto-converts to Skool's TipTap format)
curl -X POST "..." -d '{
  "action": "classroom:setBody",
  "params": {"pageId": "...", "title": "Lesson 1", "bodyMarkdown": "# Heading\n\nLesson content here..."}
}'
```

This pattern is documented end-to-end in [Publish course from markdown](../recipes/publish-course-from-markdown.md).

For batch operations (publish 10 courses at once, update covers across all courses), see [Batch update course covers](../recipes/batch-update-course-covers.md).

## Selling courses inside Skool

Two patterns:

### A. Course = part of community access

Member pays you $50/mo → gets access to community + all courses. No course-specific pricing. Simpler.

### B. Standalone course purchase

Member can buy a specific course one-time without joining the community subscription. Skool supports this via Stripe — set the price per course at creation.

Most founders start with (A) — keep it simple. Move to (B) only when you have a clear high-ticket course that justifies separate pricing.

## Course pricing in Skool — examples

| Course type | Typical price |
|---|---|
| Foundation course included with community membership | $0 (bundled) |
| Standalone evergreen course | $99-$499 one-time |
| Cohort-based program (8 weeks, 1 group) | $1,000-$5,000 one-time |
| Mastermind-level course with 1-on-1s | $5,000-$25,000 one-time |

Skool doesn't take a cut of course sales beyond your $99/mo platform fee. Stripe takes ~2.9% + $0.30 per transaction.

## Common questions

### How long can a Skool course be?

No limit. You can have a course with 1 page or 200 pages. Most successful Skool courses have 20-50 pages, each ~3-10 min consumption time.

### Can I import courses from Kajabi / Thinkific / Teachable?

No native importer. The [Apify Skool API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=glossary&utm_campaign=skool-courses&fpr=cristian) lets you push markdown-formatted course content. If you export your existing course to markdown (or Notion-to-markdown), you can republish to Skool programmatically.

### Can I require students to complete a quiz before moving on?

No. Skool has no native quiz/assignment functionality. For lighter assessment (a question in a page that members answer in comments), it works fine. For graded LMS-style assessment, use Kajabi or Thinkific.

### Can members see who has completed a course?

Members see their own completion progress. You as owner see aggregate completion rates per course in basic analytics. Per-member completion data is not exposed natively, but can be derived via the [API](../learn/skool-api.md).

### How does drip work?

Set a drip schedule per page: "available N days after the member joined". So you can have lesson 1 immediate, lesson 2 after 7 days, lesson 3 after 14 days. Useful for pacing knowledge programs.

## Related

- [How does Skool work?](how-does-skool-work.md)
- [Skool classroom](skool-classroom.md)
- [Skool features](skool-features.md)
- [Publish course from markdown (recipe)](../recipes/publish-course-from-markdown.md)
- [Skool API for course publishing](skool-api.md)

---

## Launch your Skool course today

[**→ Create your Skool community**](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial. Build your first course in <60 minutes.

*Want to publish courses from markdown? [Use this Apify actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=glossary&utm_campaign=skool-courses&fpr=cristian) — programmatic course publishing for ~$1.50/mo.*

<script type="application/ld+json">
{"@context":"https://schema.org","@type":"Course","name":"Skool Courses","description":"Skool's classroom hosts unlimited courses with folders, pages, drip schedules, and tier/level gating. $99/mo flat — no per-course fees."}
</script>
