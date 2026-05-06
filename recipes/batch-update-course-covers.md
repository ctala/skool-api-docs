# Batch update course covers

Refresh the visual identity of every course in your classroom — without resetting privacy, tier, or amount. Uses `classroom:updateCourse`'s read-then-write to safely apply only the cover change.

This is exactly how the 17 covers in [Cágala, Aprende, Repite](https://www.skool.com/cagala-aprende-repite) were updated in one batch in May 2026.

## When to use

- You changed your brand visual identity and need to refresh all covers at once
- You introduced a category color system and need to apply it across N courses
- You want to A/B test cover designs (refresh, measure click-through, refresh again)

## The critical detail: don't break privacy/tier

A naïve approach would be `PUT /courses/{id}` directly with just the cover fields. **This silently resets `privacy` to 0 (Open)** — your premium courses become public. See [classroom docs → R-PUT-COURSE](../docs/classroom.md#r-put-course--the-silent-privacy-reset-bug) for the gory details.

The actor's `classroom:updateCourse` handles this for you via read-then-write: it fetches each course's current state first, merges your changes on top, and writes the full body. Use it.

## The pipeline

```
[Plan JSON] ─→ for each course:
                  1. Render cover (HTML template → JPEG via Browserless / Playwright)
                  2. files:uploadImage (upload to Skool)
                  3. classroom:updateCourse (apply cover, preserve everything else)
                  4. Verify visually
```

## The plan structure

Define a JSON array — one entry per course — with everything needed to render its cover:

```json
[
  {
    "courseId": "32-char-hex-from-classroom-listCourses",
    "category": "ai-automatizaciones",
    "color": "#B366FF",
    "icon": "🤖",
    "label": "IA · AUTOMATIZACIONES",
    "title1": "AI AGENTS",
    "title2": "STARTER KIT",
    "subtitle": "Build your first AI agent in 2026 — WhatsApp, Make, n8n, local hardware.",
    "tag1": "WhatsApp · ventas",
    "tag2": "Dual-path Make/n8n",
    "tag3": "$0 to $200/mo",
    "tag4": "Llama local"
  },
  // ... one per course
]
```

(Field names match a typical synthwave-style template — adapt to your design.)

## Render via HTML template

Most teams render covers from a single HTML template, substituting per-course values. Browserless / Playwright / Puppeteer takes the HTML and produces a JPEG.

```javascript
async function renderCover(item, templateHtml) {
  let html = templateHtml;
  const subs = {
    __CAT__: item.color,
    __CAT_ICON__: item.icon,
    __CAT_LABEL__: item.label,
    __TITLE_LINE_1__: item.title1,
    __TITLE_LINE_2__: item.title2,
    __SUBTITLE__: item.subtitle,
    __TAG_1__: item.tag1,
    __TAG_2__: item.tag2,
    __TAG_3__: item.tag3,
    __TAG_4__: item.tag4,
  };
  for (const [k, v] of Object.entries(subs)) {
    html = html.split(k).join(v);
  }

  const r = await fetch(`https://browser.cristiantala.com/screenshot?token=${BROWSERLESS_TOKEN}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      html,
      options: { clip: { x: 0, y: 0, width: 1460, height: 752 }, type: 'jpeg', quality: 90 },
      viewport: { width: 1460, height: 752 },
    }),
  });
  return Buffer.from(await r.arrayBuffer());
}
```

(Replace `browser.cristiantala.com` with your Browserless instance, or use local Playwright.)

## Upload + apply

```javascript
async function callActor(input) {
  const r = await fetch(
    `https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=${APIFY_TOKEN}&build=latest&timeout=90`,
    { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(input) },
  );
  return JSON.parse(await r.text())[0];
}

const auth = { cookies: COOKIES, groupSlug: GROUP_SLUG };

for (const item of plan) {
  // 1. Render
  const buf = await renderCover(item, templateHtml);
  console.log(`✓ rendered ${item.courseId}: ${buf.length} bytes`);

  // 2. Upload via actor
  const upload = await callActor({
    action: 'files:uploadImage', ...auth,
    params: { bufferBase64: buf.toString('base64') },
  });

  // 3. Apply — read-then-write preserves privacy/tier/amount
  const result = await callActor({
    action: 'classroom:updateCourse', ...auth,
    params: {
      courseId: item.courseId,
      coverImage: upload.coverImageUrl,
      coverImageFile: upload.coverImageFile,
    },
  });

  if (result.success === false) {
    console.error(`❌ ${item.courseId}: ${result.errorCode}`);
    continue;
  }
  console.log(`✓ updated ${item.courseId}`);

  // Pace yourself — Skool's writes/min cap
  await new Promise(r => setTimeout(r, 1500));
}
```

## Verification

After the batch:

1. **Spot-check 2-3 courses visually** in `/classroom` — open them, confirm the new cover loads (force browser cache reset with `Cmd+Shift+R`)
2. **Verify privacy/tier preserved**: call `classroom:listCourses` and assert each course's `metadata.privacy` and `metadata.min_tier` still match the pre-batch state. If any reset to 0, the actor's read-then-write didn't run as expected — open an issue.

## Cache notes

Skool's CDN caches covers for ~5 minutes. If you re-screenshot the classroom right after the batch, the old covers may still appear. Wait 5 min, hard refresh the browser, then verify.

## Common gotchas

### Don't pass `desc` if you only want to change the cover

`classroom:updateCourse` passes-through any field you provide. If you accidentally pass an empty `desc: ""`, you'll wipe the description. The read-then-write only fills in fields you **omit** — fields you explicitly pass override.

### Skool downscales covers

Even though you upload 1460×752, Skool serves a smaller version on the classroom grid. The full-size cover only shows on hover or in the course header. Render at 1460×752 anyway — sharper downscale.

### Affiliate links in the cover image

Don't put links in the cover JPEG — they're not clickable in Skool's UI. Use the cover for visual identity; use the course `desc` for the value prop.

## See also

- [Classroom docs](../docs/classroom.md) — full data model + R-PUT-COURSE explainer
- [Files docs](../docs/files.md) — image upload flow
- [Recipe: Publish a course from markdown](publish-course-from-markdown.md) — full course creation pipeline
