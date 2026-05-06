# Changelog

All notable changes to the Skool All-in-One API actor.

The actor follows [Semantic Versioning](https://semver.org/) — `MAJOR.MINOR.PATCH`. Each release is tagged on the [Apify Store listing](https://apify.com/cristiantala/skool-all-in-one-api).

To get notified of new releases:

- ⭐ **Star and Watch** [this repo](https://github.com/ctala/skool-api-docs) on GitHub
- 📡 Subscribe to the [GitHub Releases RSS feed](https://github.com/ctala/skool-api-docs/releases.atom)
- 💬 Follow announcements in the [Apify Discord `#showcase`](https://discord.gg/apify)

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
