---
render_with_liquid: false
---

# Publish a weekly changelog post with an image, a poll, and an email to every member

The community update that most founders publish by hand every week: an image, a poll to drive replies, and the email blast so people who don't open the app still find out. All three are the pieces Skool's API exposes least obviously — and each one fails in a way that looks like success.

Production version: the Monday "Novedades de la comunidad" post in a 1,700-member community, previously the one task that could not be automated.

## What you'll build

```
[Your changelog source: repo, notes, CMS]
        ↓
   1. files:uploadImage      → fileId
   2. posts:createPoll       → pollId
   3. posts:create           → post + poll + image + email to all members
        ↓
   4. Verify by re-fetching (never by status code)
```

## Prerequisites

- Apify token + Skool cookies ([authentication](../docs/authentication.md))
- **Admin rights** on the group — `notifyAll` is admin-only
- A category id (`labelId`) if your group requires categories — get it from `groups:get`
- A throwaway community to test in. **Do not rehearse this against your real one:** each broadcast is an irreversible email to every member.

## Step 1 — Upload the image

```json
{
  "action": "files:uploadImage",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "filePath": "/local/path/changelog.png",
    "fileName": "changelog.png",
    "contentType": "image/png"
  }
}
```

Keep the returned file id. **Check that the response contains `read_url`** — if it doesn't, the image will render as an empty grey box no matter what the rest of the pipeline reports. See [files](../docs/files.md#attaching-an-image-to-a-feed-post--use-uploadimage-and-nothing-else).

## Step 2 — Create the poll

```json
{
  "action": "posts:createPoll",
  "params": { "options": ["A course", "A live session", "More templates"] }
}
```

→ `{ "pollId": "a0169196540f40f082039657d2b17755" }`

**The poll has no question field.** Skool's poll is only a list of options; the question is the post body you write in the next step. This surprises everyone once.

## Step 3 — Create the post

```json
{
  "action": "posts:create",
  "params": {
    "title": "📣 This week in the community",
    "content": "Everything that shipped.\n\nWhat should we build next?",
    "labelId": "your-category-id",
    "attachmentId": "file-id-from-step-1",
    "pollId": "poll-id-from-step-2",
    "notifyAll": true
  }
}
```

Note the `content` doubles as the poll question — that's the design, not a workaround.

## Step 4 — Verify by effect, not by status

This is the step people skip, and it's the one that matters here. **Every failure mode in this recipe returns `200`:**

| What can silently go wrong | What the API says | How to actually tell |
|---|---|---|
| The email was never sent | `200`, post created | Check an inbox. The broadcast email's footer reads *"Don't want admin broadcast emails"* — regular notifications say *"Don't want to be notified when…"* |
| The image doesn't display | `200` on all three calls, thumbnails even get generated | Open the post. Or check that step 1's response had `read_url` |
| The poll didn't attach | `200`, post created | Re-fetch the post and confirm `pollData.entries[]` holds your options |

```json
{ "action": "posts:get", "params": { "postId": "id-from-step-3" } }
```

## Production gotchas

### `notifyAll` cannot be added later — ever

Skool offers "email all members" **only at creation time**. There is no endpoint, and no UI button, to notify about a post that already exists. If you publish without it and then realise you wanted the email, your only option is deleting and re-posting.

### Skool does not validate the notify value

Internally this is a query parameter, `?notify=members`. Skool accepts *any* value: send `notify=banana` and you get `200`, a created post, and **no email** — no error, no warning, nothing in the response to distinguish it from success. If you call `api2.skool.com` directly rather than through the actor, treat this parameter as a literal you never build from a variable.

### Broadcasts are rate-limited to roughly one per 72 hours per group

A second one inside the window returns `400 — notify limit exceeded`. Two consequences:

- **The rejection is atomic: the post is NOT created.** The intuitive reading is the opposite ("the post went out, the email didn't"), and a retry based on that assumption double-posts once the quota frees.
- **If you run more than one broadcast ritual per week, they compete.** A community posting on Friday and Monday has only a couple of hours of slack: a Friday broadcast at 11:54 UTC frees the window at 11:54 UTC on Monday, so a Monday post at 14:00 UTC clears it by ~2 hours. Publish the earlier one late and the later one gets no email at all. Map your cadence against the 72h window before automating both.

### Test in a throwaway community

Every rehearsal of this recipe costs a real broadcast. Create a second Skool group with one or two members and point your test runs there — and hard-code a guard that refuses to run against your production `group_id`, because the slug is a variable and a copy-paste changes it without anyone noticing.

## See also

- [Posts](../docs/posts.md#postscreatepoll--create-a-poll) — full `posts:create` and `posts:createPoll` reference
- [Files](../docs/files.md) — upload rules, `privacy` flag, and why `uploadFile` breaks post images
- [Mirror your newsletter as a Skool post](newsletter-to-skool-post.md) — the same publishing pipeline, different source
