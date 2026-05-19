---
title: "Skool Classroom — How the Courses System Works (2026)"
description: "The Skool classroom hosts your courses. Structure: courses → folders → pages. Drip, gating, tier access, gamification unlocks. Markdown-friendly via API."
slug: /learn/skool-classroom
type: glossary
primary_keyword: "skool classroom"
search_volume_monthly: 40
funnel: B
playbook: glossary
last_updated: 2026-05-19
canonical: https://github.com/ctala/skool-api-docs/blob/main/learn/skool-classroom.md
---

# Skool Classroom

> **TL;DR.** The Classroom is the courses section of every Skool community. It hosts unlimited courses, each a tree of folders + pages with rich content. Included in [$99/mo](../guide/skool-pricing.md). Gate by tier or gamification level. Drip on schedule. Markdown body content via the [Apify API actor](../integrations/skool-python.md).

## What "Classroom" means in Skool

The Classroom tab in every Skool community shows the courses you've published. Members see a grid of course cards (with cover images you upload), click into one, and consume the content page by page.

Structure:

```
Classroom
├── Course 1 (cover image, title, description)
│   ├── Folder A
│   │   ├── Page 1.1
│   │   ├── Page 1.2
│   │   └── Page 1.3
│   ├── Folder B
│   │   ├── Page 2.1
│   │   └── Page 2.2
│   └── (top-level pages without a folder)
├── Course 2
│   └── ...
└── Course N
```

Folders are optional — for short courses (≤5 pages), pages can sit directly under the course root.

## What lives on a page

Each page can include:

- Rich text (headings, lists, blockquotes, code blocks)
- Video embeds (YouTube, Vimeo, Loom)
- Image attachments
- Downloadable files
- Inline links

The body editor is **TipTap-based** (Skool's internal rich text format). You write in the WYSIWYG UI normally. If you publish via API, [markdown auto-converts to TipTap](../integrations/skool-python.md).

## Access control on a course

You set 4 dimensions of access:

| Dimension | Options |
|---|---|
| **Privacy** | 0=public, 1=private, 2=tier-gated, 3=level-gated, 4=archived |
| **Min Tier** | Members must be at this paid tier or above |
| **Min Level** | Members must have reached this gamification level |
| **Drip schedule** | Per-page: available N days after member joined |

These combine. Example: a course with `privacy=2, minTier=2, drip=14` means "members on tier 2 or higher, courses revealed page-by-page over 14 days from their join date".

## Gamification unlocks

This is the underrated part. You can set a course to unlock only when a member reaches a specific level (1-9). Combined with the leaderboard, this creates a natural retention loop:

- Member sees "Level 5 unlocks the Advanced Course"
- Member engages more to climb levels
- Member reaches level 5 → unlocks the course → consumes more → posts about it → others see → community engagement compounds

This is the single highest-leverage classroom feature in Skool. Most owners underuse it.

## Drip schedule

For knowledge programs that benefit from pacing:

| Page | Available |
|---|---|
| Introduction | Day 0 (immediately on member join) |
| Module 1 | Day 0 |
| Module 2 | Day 7 |
| Module 3 | Day 14 |
| Module 4 | Day 21 |
| Bonus | Day 30 |

Members see locked pages as "available in X days". Builds anticipation. Reduces overwhelm.

## Creating courses — UI vs API

### UI

Classroom → Create Course → fill in title/desc/cover → add folders → add pages → set body via the rich editor → set privacy/tier/level/drip.

Time per course: ~30-90 min depending on content length.

### API (the [Apify actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=glossary&utm_campaign=skool-classroom))

Programmatic publishing for when content lives in markdown files:

```bash
# Create course
{"action": "classroom:createCourse", "params": {"title": "...", "desc": "...", "privacy": 2, "minTier": 1}}

# Create folder
{"action": "classroom:createFolder", "params": {"parentCourseId": "...", "title": "Module 1"}}

# Create page (empty)
{"action": "classroom:createPage", "params": {"courseId": "...", "parentId": "...", "title": "Page 1"}}

# Set page body (markdown auto-converts to TipTap)
{"action": "classroom:setBody", "params": {"pageId": "...", "title": "Page 1", "bodyMarkdown": "# Heading\n\n..."}}

# Update course metadata (cover, privacy, etc.) without resetting other fields
{"action": "classroom:updateCourse", "params": {"courseId": "...", "coverImage": "...", "coverImageFile": "..."}}
```

Time per course via API (markdown already exists): ~5-10 min for a 20-page course.

See [Publish course from markdown](../recipes/publish-course-from-markdown.md) for the end-to-end recipe.

## The R-PUT-COURSE quirk (for developers)

When updating a course's privacy or tier, do NOT use `PUT /courses/{id}` directly with a partial body — Skool's internal endpoint silently resets `privacy` to 0 (public) when you omit the field. Always use `classroom:updateCourse` which does **read-then-write**: fetches current values, merges your updates, writes the full object.

This is the most common silent failure when building your own Skool API client. The actor handles it correctly.

## Member experience

Members navigate to Classroom → see a grid of courses they have access to (locked ones either hidden or grayed out depending on settings) → click into a course → consume page-by-page.

Progress tracking is per-member, per-page. They see their own "completed" markers. You as owner see aggregate completion rates.

## Limitations

- No native quizzes or assignments
- No native cohort grouping (everyone consumes individually)
- No native peer review or grading
- No certificates of completion (you can hack this with a final page that says "you completed!" and a downloadable PDF cert via attachment)
- No native course progress sharing on the community feed

For most knowledge products, these limitations are acceptable trade-offs for the simplicity. For LMS-grade course delivery, use Kajabi/Thinkific instead.

## Related

- [Skool courses](skool-courses.md)
- [How does Skool work?](how-does-skool-work.md)
- [Skool features](skool-features.md)
- [Publish course from markdown (recipe)](../recipes/publish-course-from-markdown.md)
- [Skool API documentation](skool-api-documentation.md)

---

## Launch your classroom today

[**→ Create your Skool community**](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day trial. Build your first course in <60 min.

*Publishing from markdown? [Use this Apify actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=glossary&utm_campaign=skool-classroom) — programmatic publishing for ~$1.50/mo.*

<script type="application/ld+json">
{"@context":"https://schema.org","@type":"DefinedTerm","name":"Skool Classroom","description":"The Classroom is the courses section of Skool — unlimited courses, each a tree of folders + pages. Tier and gamification-level gating, drip scheduling.","inDefinedTermSet":"https://github.com/ctala/skool-api-docs"}
</script>
