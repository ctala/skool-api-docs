# Changelog

All notable changes to the Skool All-in-One API actor.

The actor follows [Semantic Versioning](https://semver.org/) — `MAJOR.MINOR.PATCH`. Each release is tagged on the [Apify Store listing](https://apify.com/cristiantala/skool-all-in-one-api?fpr=cristian).

To get notified of new releases:

- ⭐ **Star and Watch** [this repo](https://github.com/ctala/skool-api-docs) on GitHub
- 📡 Subscribe to the [GitHub Releases RSS feed](https://github.com/ctala/skool-api-docs/releases.atom)
- 💬 Follow announcements in the [Apify Discord `#showcase`](https://discord.gg/apify)

---

## [0.3.48] — 2026-07-31

**Promoted to `latest`.** The three composer features the API never exposed: email-all-members, polls, and image attachments.

### Added

- **`notifyAll` on `posts:create`** — the "Send email to all members" toggle. Admin-only, and **impossible to add later**: Skool only offers the email at creation time.
- **`posts:createPoll`** — `options[]` → `pollId`, attached via `posts:create`. Two calls, because a poll is its own object. **Polls have no title or question field** — the question is the post's `content`.
- **`attachmentId` on `posts:create`** — attach an image uploaded with `files:uploadImage`. One file id as a string, not an array.
- `files:uploadImage` now takes `contentType`, so PNGs stop getting a `.jpg` URL that 404s.

### Three ways these fail while returning `200`

Worth reading before automating any of them — none of these surface as an error:

- **A wrong notify value emails nobody.** Skool doesn't validate it: an unrecognised value creates the post and sends nothing, silently.
- **A privately-uploaded image renders as an empty grey box.** Using `files:uploadFile` (which sends `privacy: 1`, correct for classroom resources) for a post image succeeds at every step — upload, S3, post — and the response merely omits `read_url`. Use `files:uploadImage`.
- **Broadcasts are rate-limited (~72h per group), and the rejection is atomic.** On `notify limit exceeded` the post is **not** created. Retrying on the assumption that it was double-posts.

Full guidance: [posts](docs/posts.md), [files](docs/files.md), and the recipe [Weekly changelog with poll + broadcast](recipes/weekly-changelog-post-with-poll-and-broadcast.md).

---

## [0.3.37] — 2026-07-09

**Promoted to `latest`.** Adds the notifications surface.

### Added
- `notifications:list` — read the account's notification feed (mentions, replies, comments, likes, membership requests), newest-first, with cursor pagination. Cross-group. Each item's `metadata.data` is parsed into flat fields (`title`, `content`, `action`, `imageUrl`) plus a relative deep-link (`?p=<commentId>`).
- `notifications:markRead` — mark one notification as read.
- `notifications:markAllRead` — mark all as read for the group. **Effect is deferred**: the call returns `200` first and the read state propagates a few seconds later — poll `notifications:list` to confirm.

See [Notifications docs](https://skool-api.cristiantala.com/docs/notifications/).

---

## [0.3.8] — 2026-05-06

**Promoted to `latest`.** Production release. All previous tags retired.

### Added
- `classroom:updateCourse` — read-then-write update of any course/page field. Internally fetches current state, merges your changes, writes the full body. Any field you don't pass is preserved. Avoids the silent privacy-reset bug confirmed against 12 production courses.
- `system:health` — no-auth, no-Skool ping action. Returns `{ok, version, node, timestamp}`. Used as INPUT_SCHEMA default so Apify's daily quality check always passes.
- `classroom:listCourses` — list top-level courses for a group
- `classroom:getTree` — recursive tree of folders + pages for a course
- `classroom:createCourse` / `createFolder` / `createPage` / `setBody` / `deleteUnit`
- `files:uploadImage` — upload an image, get back `{coverImageUrl, coverImageFile}` ready for course/group settings
- `groups:get` — group metadata via Skool's SSR
- `groups:setAutoDM` — update Auto DM message for new members (300-char limit, `#NAME#` + `#GROUPNAME#` tokens)
- Markdown→TipTap converter for course pages (zero deps, hand-rolled). Supports headings, bold, italic, code, links, blockquotes, lists, code blocks, tables.
- Structured error hints: `MISSING_CATEGORY`, `TITLE_TOO_LONG`, `INSUFFICIENT_TIER`, `WAF_EXPIRED`, `BUILDID_STALE`, `NOT_FOUND`, `RATE_LIMIT`, `NETWORK_ERROR`, `UNKNOWN_ERROR`. Each comes with a `hint` field for actionable recovery.

### Changed
- **Never-throw policy now strict**: every error path catches and ships a `{success:false, errorCode, hint, retryable}` payload. Runs always end `SUCCEEDED`. The actor never trips Apify's `UNDER_MAINTENANCE` flag.
- `classroom:updateCourse` reverted from naïve PUT to read-then-write after confirming the silent privacy reset on production data.
- Markdown converter improved: blockquote callouts now render cohesively (lists nested inside flatten to `• ` so the border stays unbroken). Blank lines no longer emit empty paragraphs (TipTap renders block spacing via CSS — empties doubled the whitespace).

### Fixed
- Auto-retry on stale `buildId` (Skool ~weekly deploy rotation)
- Auto-retry on expired WAF token (~3.5 day rotation)
- HTTP 5xx + network errors retried with exponential backoff (no longer surface as terminal errors)

### Documentation
- Full docs repo published: https://github.com/ctala/skool-api-docs
- 8 reference docs: getting-started, authentication, posts, members, classroom, files, groups, error-handling
- 6 production-grade recipes (n8n + raw)
- AI agent integration guide (Claude / OpenAI / Gemini function calling, MCP, LangChain, Claude Code Skill)
- Launch post on Hashnode: [I Built the Most Complete Skool API — and What I Learned Reverse-Engineering It](https://cristiantalasanchez.hashnode.dev/i-built-the-most-complete-skool-api-read-and-write-and-what-i-learned-reverse-engineering-it)

---

## [0.2.3] — 2026-04-09

**`latest` from Apr 9 to May 6.**

### Added
- PPE pricing model activated (Pay-Per-Event)
- `posts:filter` action (date range, unanswered, label combinations)
- `members:batchApprove` for bulk operations
- Nested comment trees (`replies` array on each comment)

### Known issues (later fixed in 0.3.x)
- `notice: UNDER_MAINTENANCE` flag tripped on May 1 incident — auto-recovery was missing for failure cases. **Resolved in 0.3.0+** with the never-throw policy.

---

## [0.2.0] — 2026-04 (early)

### Added
- Structured failure payloads (`{success:false, error, errorCode}`) for expected errors. Runs no longer mark `FAILED` for known auth / not-found / rate-limit cases.
- `auth:login` returns reusable cookies (~3.5 day TTL). Subsequent calls use cookies, skip Playwright.

---

## [0.1.x] — 2026-Q1

Initial public release. Read-only support for posts, members, comments. No write operations.

---

## Versioning policy

- **MAJOR**: Breaking changes to action shapes or response structure
- **MINOR**: New actions, new fields in response, new error codes
- **PATCH**: Bug fixes, performance improvements, documentation

The `latest` tag on Apify always points to the current stable release. The `beta` tag points to the next release for early adopters.

To pin to a specific version:

```bash
# Use ?build=0.3.8 in your Apify API call
https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=...&build=0.3.8
```

To follow `latest` (recommended):

```bash
https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=...&build=latest
```

## Issues

Bug reports + feature requests: https://github.com/ctala/skool-api-docs/issues
