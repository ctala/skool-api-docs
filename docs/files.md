# Files

Upload images to Skool's storage. Used for course covers (1460×752), group cover (1084×576), group icon (128×128), and any other image asset Skool's UI accepts.

## Action

### `files:uploadImage`

Two ways to provide the image. Pick one.

**Option A: base64-encoded buffer (recommended for actor input)**

```json
{
  "action": "files:uploadImage",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "bufferBase64": "<base64-encoded image bytes>"
  }
}
```

In Node:

```javascript
const buf = readFileSync('/path/to/cover.jpg');
const result = await callActor({
  action: 'files:uploadImage', cookies, groupSlug,
  params: { bufferBase64: buf.toString('base64') },
});
```

**Option B: remote URL (the actor fetches it for you)**

```json
{
  "action": "files:uploadImage",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "imageUrl": "https://assets.cristiantala.com/covers/my-course.jpg"
  }
}
```

The actor fetches the URL, validates the MIME type, and uploads to Skool's storage.

## Response

```json
{
  "success": true,
  "coverImageUrl": "https://assets.skool.com/f/{groupId}/{hash}.jpg",
  "coverImageFile": "32-char-hex-file-id"
}
```

You **must pass both** `coverImageUrl` AND `coverImageFile` to any subsequent `classroom:createCourse` / `classroom:updateCourse` call. The URL is the read path; the file id is the storage reference. They're paired.

## What Skool does with the upload

Skool's storage flow has 3 internal steps that the actor abstracts:

1. **Register**: `POST /files` with metadata (filename, content_type, content_length, owner_id) → receives a **presigned S3 write URL** (1-hour TTL) and the future read URL + file id.
2. **Upload**: `PUT <presigned URL>` with the actual bytes + headers `Content-Type: image/jpeg` + `x-amz-acl: public-read`.
3. **Reference**: pass the read URL + file id to whatever resource you're creating (course, group settings).

You don't see any of this. The actor returns the final `{coverImageUrl, coverImageFile}` ready to use.

## Format & size guidance

| Use case | Recommended format | Recommended dims |
|---|---|---|
| Course cover | JPEG | 1460×752 |
| Group cover | JPEG | 1084×576 |
| Group icon | JPEG / PNG | 512×512 (Skool downscales to 128×128 — start big for sharp result) |
| Inline image (in About body) | JPEG / PNG | Whatever fits the layout |

Skool re-encodes server-side: PNG and WebP get converted to JPG. SVG is rejected. Animated GIF is converted to a still frame.

## Storage location

Uploaded files live at:

```
https://assets.skool.com/f/{groupId}/{contentHash}.jpg
```

This means files are **scoped to your group**. You can't reference a file uploaded to one group from another group's content.

## Common gotchas

### External image URLs in `coverImage`

If you pass a Skool-external URL (e.g. your own CDN) directly to `classroom:createCourse` without uploading first, Skool **silently rejects it** — the cover ends up empty. Always upload via `files:uploadImage` first.

### Presigned URL expiry

The S3 presigned write URL is valid for ~1 hour. The actor uploads immediately within the same run, so you never see this timeout — but if you reverse-engineer your own client, don't cache the presigned URL.

### MIME type mismatch

Sending a `.png` file with `Content-Type: image/jpeg` makes the upload succeed but breaks the served thumbnail. The actor reads the magic bytes to detect the actual format and sets headers correctly.

### File size limits

Skool accepts up to ~10 MB per image (empirically — not documented). Above that, the upload returns a 413. Compress before uploading; for course covers, 80-90% JPEG quality is plenty.

## Code examples

### Generating a cover with a HTML template + Browserless

If you produce covers from a HTML template (e.g. synthwave-style classroom covers), the typical flow is:

```javascript
// 1. Render HTML → JPEG via Browserless / Playwright / Puppeteer
const jpegBytes = await renderCoverViaBrowserless(htmlTemplate);

// 2. Upload via actor
const upload = await callActor({
  action: 'files:uploadImage', cookies, groupSlug,
  params: { bufferBase64: jpegBytes.toString('base64') },
});

// 3. Apply to a course
await callActor({
  action: 'classroom:updateCourse', cookies, groupSlug,
  params: {
    courseId: '...',
    coverImage: upload.coverImageUrl,
    coverImageFile: upload.coverImageFile,
  },
});
```

This is the exact pattern in the [batch update course covers recipe](../recipes/batch-update-course-covers.md).

### `files:uploadFile` — non-image uploads (PDF, ZIP, sheets) for classroom resources

Use this for any non-image file you want to attach as a **lesson resource** (PDF cheatsheets, workflow JSONs, ZIP bundles). Different bucket + ACL from `files:uploadImage` — and **not interchangeable**.

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

Use the `file.id` in [`classroom:updateResources`](classroom.md#classroomupdateresources) to attach the file to a lesson.

#### Why this exists separately from `uploadImage`

Skool's `POST /files` accepts a `privacy` flag that determines bucket + ACL:

| `privacy` | Bucket | ACL | Use case |
|---|---|---|---|
| `0` (default) | `sk-groups-dev-files` | `public-read` | Cover images (URL public, `.jpg` suffix) |
| `1` | `sk-groups-files` | `private` (signed URLs on-demand) | Classroom Resources |

The actor's `files:uploadImage` always sends `privacy: 0`, and `files:uploadFile` always sends `privacy: 1`. **You can't change the flag after upload** — pick the right wrapper.

If you try to use a `privacy: 0` file as a classroom resource, Skool rejects with `400 invalid file ... privacy: 0`. Re-upload with `files:uploadFile`.

#### Direct GET returns 403 for `privacy: 1` files

`assets.skool.com/...` URLs for private files return `403 Access Denied` because the bucket policy blocks public access. Skool generates signed URLs on-demand when a member clicks Download from a lesson page. This is correct behavior, not a bug.

See the full recipe: [Attach files to lesson pages](../recipes/attach-files-to-lessons.md).

## See also

- [Classroom](classroom.md) — courses use covers heavily (and lesson resources need `uploadFile`)
- [Groups](groups.md) — group icon + cover are also `files:uploadImage` + `groups:*` writes
