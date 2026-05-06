# Publish a Skool course from markdown files

Take a directory tree of markdown files, ship a fully-rendered Skool course with cover, folders, lessons, tier gating — in one script. No clicking "New page" 60 times.

This is the exact pattern used to publish [AI Agents Starter Kit · LATAM](https://www.skool.com/cagala-aprende-repite/classroom) (5 modules × 19 lessons) in a single command.

## What you'll build

```
your-course-repo/
├── _index.md                            ← course metadata
├── assets/
│   └── cover.jpg                        ← 1460×752 cover
├── M01-module-name/
│   ├── _index.md                        ← module description
│   ├── L1.1-lesson-slug.md              ← lesson body (markdown)
│   └── L1.2-lesson-slug.md
└── M02-other-module/
    └── L2.1-lesson-slug.md
```

Run `node publish.mjs` → course exists in Skool with everything wired.

## Prerequisites

- Apify token + Skool cookies
- A skool-js-compatible client (or you can use raw `curl` — see below)
- Your course content in the directory tree above
- Cover JPEG at `assets/cover.jpg` (1460×752 recommended)

## Script

```javascript
// publish.mjs
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { resolve } from 'node:path';

const APIFY_TOKEN = process.env.APIFY_TOKEN;
const COOKIES = process.env.SKOOL_COOKIES;
const GROUP_SLUG = 'your-community-slug';
const COURSE_ROOT = '/path/to/your-course-repo';

async function call(input, timeout = 90) {
  const r = await fetch(
    `https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=${APIFY_TOKEN}&build=latest&timeout=${timeout}`,
    { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(input) },
  );
  return JSON.parse(await r.text())[0];
}

const auth = { cookies: COOKIES, groupSlug: GROUP_SLUG };

// 1. Read course metadata from _index.md (you parse this however you like)
const indexMd = readFileSync(resolve(COURSE_ROOT, '_index.md'), 'utf8');
// Example: extract title, desc, privacy, minTier from frontmatter or markdown
const COURSE_TITLE = '🤖 My New Course';
const COURSE_DESC = 'Concise tile description, ≤500 chars.';

// 2. Discover modules + lessons from filesystem
const modules = readdirSync(COURSE_ROOT)
  .filter((f) => /^M\d+-/.test(f))
  .sort()
  .map((modDir) => ({
    folderTitle: deriveModuleTitle(modDir, indexMd),  // your call
    files: readdirSync(resolve(COURSE_ROOT, modDir))
      .filter((f) => /^L\d+\.\d+-.*\.md$/.test(f))
      .sort()
      .map((file) => ({
        title: deriveLessonTitle(file),
        path: resolve(COURSE_ROOT, modDir, file),
      })),
  }));

// 3. Validate titles ≤ 50 chars BEFORE any network call
const allTitles = [COURSE_TITLE, ...modules.map(m => m.folderTitle), ...modules.flatMap(m => m.files.map(f => f.title))];
const overLimit = allTitles.filter((t) => t.length > 50);
if (overLimit.length) {
  console.error('❌ Titles over 50-char Skool limit:', overLimit);
  process.exit(1);
}

// 4. Upload cover
const coverBuf = readFileSync(resolve(COURSE_ROOT, 'assets', 'cover.jpg'));
const cover = await call({
  action: 'files:uploadImage', ...auth,
  params: { bufferBase64: coverBuf.toString('base64') },
});
console.log(`✓ cover uploaded: ${cover.coverImageUrl.slice(-40)}`);

// 5. Create course
const course = await call({
  action: 'classroom:createCourse', ...auth,
  params: {
    title: COURSE_TITLE,
    desc: COURSE_DESC,
    coverImage: cover.coverImageUrl,
    coverImageFile: cover.coverImageFile,
    privacy: 1,        // Level unlock
    minTier: 2,        // Premium-only (adapt to your group's tier mapping)
    state: 2,          // active
  },
});
console.log(`✓ course created: ${course.id}`);

// 6. Skool auto-creates a placeholder "New page" — delete it
const tree = await call({ action: 'classroom:getTree', ...auth, params: { courseId: course.id } });
for (const child of tree.children ?? []) {
  if (child.course?.metadata?.title === 'New page') {
    await call({ action: 'classroom:deleteUnit', ...auth, params: { id: child.course.id } });
  }
}

// 7. Create folders + pages + bodies
for (const mod of modules) {
  const folder = await call({
    action: 'classroom:createFolder', ...auth,
    params: { parentCourseId: course.id, title: mod.folderTitle },
  });
  console.log(`📁 ${mod.folderTitle}`);

  for (const lesson of mod.files) {
    const page = await call({
      action: 'classroom:createPage', ...auth,
      params: { courseId: course.id, parentId: folder.id, title: lesson.title },
    });
    const body = readFileSync(lesson.path, 'utf8');
    await call({
      action: 'classroom:setBody', ...auth,
      params: { pageId: page.id, title: lesson.title, bodyMarkdown: body },
    });
    console.log(`   ✓ ${lesson.title}`);
    // Pace yourself — Skool's writes/min limit
    await new Promise(r => setTimeout(r, 1500));
  }
}

console.log(`\n✅ Course published: https://www.skool.com/${GROUP_SLUG}/classroom/${course.id}`);
```

## What gets converted automatically

The actor's `bodyMarkdown` parameter accepts standard markdown and converts to Skool's TipTap JSON. Supported syntax:

- Headings (H2, H3 — H1 is stripped because Skool puts the page title separately)
- Paragraphs with **bold**, *italic*, `code`, [links](url)
- Bullet and ordered lists
- Code blocks (fenced)
- Blockquotes (lists nested inside flatten to `• ` prefix paragraphs)
- Simple tables (≤5 cols × ≤10 rows × ≤30 chars/cell render as monospace code block; larger tables degrade to bullet list with bold key prefixes)

Markdown features Skool's TipTap doesn't render:
- ❌ Inline images (Skool needs them as separate blocks; not yet auto-handled)
- ❌ Footnotes
- ❌ HTML embeds (use `videoId` for video, not `<iframe>`)

See [classroom docs](../docs/classroom.md#markdown--tiptap-converter) for the full converter behavior.

## Re-running the script (idempotent it ain't)

This script **creates a new course every time** — it doesn't update an existing one. To re-publish:

1. **Delete** the existing course: `classroom:deleteUnit` with the old course id (cascades all folders + pages)
2. Re-run the script

For partial updates (just one lesson body), use `classroom:setBody` directly with the existing pageId. To make the script idempotent (update if exists, create otherwise), maintain a `course-state.json` mapping titles → pageIds and call `classroom:setBody` instead of `classroom:createPage` when you have a hit.

## Production tips

### Validate titles upfront

The 50-char limit applies to **every** title (course, folder, page). The script above validates before the first network call — fail fast, save quota.

### State `1` for staging

While building a course, use `state: 1` (draft) so non-admin members don't see it. Flip to `state: 2` (active) when you're ready to launch.

### Cover-only updates afterward

Once the course exists, refresh covers via `classroom:updateCourse` (read-then-write — preserves privacy/tier). [Recipe →](batch-update-course-covers.md)

### Tier mapping per community

`minTier: 2` means "Premium" in Cágala, Aprende, Repite. In your community it might mean something else. Read `groups:get` first to see the tier definitions of your group.

## See also

- [Classroom docs](../docs/classroom.md)
- [Files docs](../docs/files.md) — cover upload flow
- [Recipe: Batch update course covers](batch-update-course-covers.md) — partner recipe for refreshes
