---
render_with_liquid: false
---

# Mirror your newsletter as a Skool community post

You publish a newsletter (Listmonk, ConvertKit, Beehiiv, Mailchimp). 80% of the value should also live inside your community — but you don't want to copy-paste manually every week. This recipe pipes the newsletter HTML/markdown into a Skool community post automatically, with proper formatting and images intact.

Production version: every Monday 9am Chile, the [Navegando Sin Un Mapa](https://cristiantala.com/blog) newsletter (Listmonk, 2,300 subs) auto-mirrors as a post in the CAR community.

## What you'll build

```
[Newsletter platform] ─→ webhook on send
                              ↓
                          [n8n / your script]
                              ↓
                          1. Strip HTML, convert to plain text + light markdown
                          2. Extract images, upload to Skool via files:uploadImage
                          3. posts:create with the rendered content
                              ↓
                          [Skool community post visible to all members]
```

## Prerequisites

- A way to trigger on newsletter send (webhook from your platform, or an RSS feed you poll)
- Apify token + Skool cookies
- Knowledge that Skool **posts are plain text only** — see [posts docs](../docs/posts.md#content-format-reference). HTML tags render literally.

## Listmonk → Skool example

Listmonk has webhook hooks. Configure one to fire on `campaign_finished`:

```
URL: https://your-n8n.com/webhook/skool-mirror
Method: POST
Body: {"campaign_id": {{ campaign.id }}, "subject": "{{ campaign.subject }}"}
```

In n8n:

### Node 1: Webhook trigger

Receives `{campaign_id, subject}`.

### Node 2: Fetch campaign body from Listmonk

```
GET https://listmonk.your-domain.com/api/campaigns/{{$json.campaign_id}}
```

Returns the campaign with `body` (HTML).

### Node 3: HTML → plain text + markdown

```javascript
// In an n8n Function node
const html = $json.data.body;

// Use a simple HTML-to-text library (e.g. html-to-text or your own regex)
let text = html
  .replace(/<h1[^>]*>(.*?)<\/h1>/gi, '\n\n$1\n')        // H1s as separator
  .replace(/<h2[^>]*>(.*?)<\/h2>/gi, '\n\n$1\n')        // H2s
  .replace(/<strong[^>]*>(.*?)<\/strong>/gi, '$1')      // strip bold (Skool doesn't render)
  .replace(/<em[^>]*>(.*?)<\/em>/gi, '$1')              // strip italic
  .replace(/<a[^>]*href="([^"]*)"[^>]*>(.*?)<\/a>/gi, '$2 ($1)')  // anchor → "text (url)"
  .replace(/<li[^>]*>(.*?)<\/li>/gi, '• $1\n')          // list items
  .replace(/<\/?p[^>]*>/gi, '\n\n')
  .replace(/<br[^>]*>/gi, '\n')
  .replace(/<img[^>]*src="([^"]*)"[^>]*>/gi, '\n[image: $1]\n')  // mark image positions
  .replace(/<[^>]+>/g, '')                              // strip all other tags
  .replace(/&nbsp;/g, ' ')
  .replace(/&amp;/g, '&')
  .replace(/&lt;/g, '<')
  .replace(/&gt;/g, '>')
  .replace(/\n{3,}/g, '\n\n')                          // collapse runs of newlines
  .trim();

return { text, subject: $json.subject };
```

### Node 4: Detect + handle images

For each `[image: URL]` marker in the text, you have two options:

**Option A — Strip images** (simplest). Skool posts don't render embedded images well; just remove the markers:

```javascript
text = text.replace(/\[image: [^\]]+\]\n?/g, '');
```

**Option B — Upload to Skool** (preserves visuals). For each image URL:

```javascript
// Fetch the image
const imgRes = await fetch(imageUrl);
const buf = Buffer.from(await imgRes.arrayBuffer());

// Upload via actor
const upload = await callActor({
  action: 'files:uploadImage', cookies, groupSlug,
  params: { bufferBase64: buf.toString('base64') },
});

// Replace marker with Skool URL — works as image embed in post body if Skool detects it
text = text.replace(`[image: ${imageUrl}]`, upload.coverImageUrl);
```

(Note: Skool's post rendering for inline images is hit-or-miss. For visual-heavy newsletters, consider linking to the original web version: `[See full version with images](https://yoursite.com/newsletter/...)`.)

### Node 5: Append CTA back to newsletter

End the post with a clear "where the original lives" + a question to drive replies:

```
---

📬 Esta es la versión comunidad del newsletter "Navegando Sin Un Mapa" — versión web con imágenes:
https://cristiantala.com/newsletter/{{slug}}

¿Cuál te resonó más? Comenta acá 👇
```

### Node 6: Create the Skool post

```json
{
  "action": "posts:create",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "title": "📬 {{ $json.subject }}",
    "content": "{{ $json.text }}",
    "labelId": "newsletter-category-id"
  }
}
```

If your community has categories, use a `Newsletter` or `Insights` category so the post is filterable.

## Production gotchas

### Frequency

Mirroring **every** newsletter floods the feed. Pick:
- Once a week (e.g. only Monday's flagship newsletter)
- Manual trigger (dropdown in n8n: "mirror this campaign? yes/no")
- Filter by category/tag (only mirror campaigns tagged `community-mirror`)

### Subject line as Skool title

Skool's title cap is 50 chars. If your newsletter subjects routinely exceed that, you need a strategy:
- Take the first 47 chars + `...`
- Define a separate "skool subject" field in your newsletter platform
- Use a shorter version in your campaign template

### Author identity

The post is created **as the user whose cookies you used**. If that's a "newsletter bot" sub-account, members see it as bot content (lower engagement). Use the founder's account so it feels personal.

### Engagement spike → rate limit risk

A hot newsletter post can attract 50+ comments in a few hours. If you also have an auto-reply workflow running (see [reply-unanswered-posts.md](reply-unanswered-posts.md)), that workflow may try to reply to each new comment as it appears. Fine in normal usage; risky if both run in tight loops. Add a "skip newsletter posts" filter to your auto-replier if needed.

### Mirror direction

This recipe goes Newsletter → Skool. The reverse (Skool post → email blast to your subscribers) is a different flow:

```
posts:list (filter pinned, date >= last_blast)
    ↓
For each: convert content + render newsletter HTML + send via Listmonk API
```

That's a bigger recipe — out of scope here. Open an issue if you want me to write it up.

## See also

- [Posts & Comments](../docs/posts.md) — content format constraints
- [Files](../docs/files.md) — image upload flow
- [Recipe: Reply to unanswered posts](reply-unanswered-posts.md) — companion automation
