# Groups

Read your group's metadata + update settings: description, Auto DM message, cover image, icon.

## Read action

### `groups:get`

```json
{
  "action": "groups:get",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "slug": "your-community" }
}
```

Returns the full group object (via Skool's SSR `_next/data` endpoint). Useful fields in the response:

- `id` — the 32-char hex group id (you'll need this for direct REST calls if you bypass the actor)
- `metadata.title` — display name
- `metadata.description` — sidebar description (≤150 chars)
- `metadata.privacy` — `public`, `private`, etc.
- `metadata.afl_percent` — affiliate commission % if enabled
- `metadata.label_options` — categories available for `posts:create` (use these as `labelId`)
- `metadata.tier_options` — paid tier definitions if any
- `metadata.logo_url` — current group icon (128×128)
- `metadata.logo_big_url` — current group cover (1084×576)

## Write actions

### `groups:setAutoDM` — update Auto DM message for new members

```json
{
  "action": "groups:setAutoDM",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "message": "Welcome #NAME# to #GROUPNAME#! Start with the 'Empieza Aquí' course in classroom — it'll save you weeks."
  }
}
```

| Token | Replaced with |
|---|---|
| `#NAME#` | Member's first name |
| `#GROUPNAME#` | Group's display name |

Constraints:

- **300-char limit** (validated by Skool UI; the actor returns `INPUT_VALIDATION` if exceeded)
- Plain text only — newlines via `\n`, no markdown / HTML
- The Auto DM **plugin must be enabled** in Settings → Plugins for the message to actually fire on new joins. The actor sets the message regardless; toggling the plugin is a separate action not yet exposed.

### Direct PUT for description, cover, icon

The full group settings update goes through `PUT /groups/{groupId}` (not yet wrapped as a single actor action). Shape:

```bash
curl -X PUT "https://api2.skool.com/groups/{groupId}" \
  -H "Cookie: $COOKIES" \
  -H 'Content-Type: application/json' \
  -H 'Origin: https://www.skool.com' \
  -H 'Referer: https://www.skool.com/your-community' \
  -d '{
    "remove_logo": false,
    "remove_logo_big": false,
    "description": "Founders LATAM aprendiendo de tropiezos reales — no de gurúes.",
    "logo": "<icon URL from files:uploadImage>",
    "logo_big": "<cover URL from files:uploadImage>"
  }'
```

Field map:

| Body field | UI label | Maps to (in `groups:get` response) |
|---|---|---|
| `description` | Group description (sidebar) | `metadata.description` |
| `logo` | Icon (128×128) | `metadata.logo_url` |
| `logo_big` | Cover (1084×576) | `metadata.logo_big_url` |
| `remove_logo` | (delete icon) | — |
| `remove_logo_big` | (delete cover) | — |

> **Coming soon as actor action**: `groups:update` to wrap this in a typed call. Until then, use the actor's `auth:login` to get cookies and call `api2.skool.com` directly from your stack.

## Discovery (SEO inside Skool)

Skool's "Discovery" tab (where new users browse communities) uses fields from `metadata`:

| Field | Purpose |
|---|---|
| `metadata.discovery_keywords` | Up to 11 keywords/tags for in-Skool search |
| `metadata.category` | Skool's category (e.g. `self-improvement`, `business`) — **set by Skool, not the owner** |
| `metadata.language` | Group language code (`ES`, `EN`, etc.) |
| `metadata.is_in_discovery` | Whether the group appears in Discovery results |

These can be edited from Settings → Discovery in the Skool UI. Endpoint not yet captured by the actor.

## Common gotchas

### `groups:get` via REST returns 403

Direct calls to `api2.skool.com/groups/{slug}` get blocked by CloudFront WAF if you're missing `Origin` + `Referer` + `User-Agent` headers. The actor's `groups:get` uses Skool's SSR endpoint instead, which is friendlier — always go through the actor for reads.

### Updating partial fields

Like courses (R-PUT-COURSE), the group `PUT` is partial-friendly **for the description** but you should still send `remove_logo: false` and `remove_logo_big: false` explicitly to avoid accidentally clearing your icon/cover. The actor will eventually wrap this with the same read-then-write safety as `classroom:updateCourse`.

### Auto DM toggle vs message

`groups:setAutoDM` sets the **message text**. Whether the Auto DM **fires** on new joins depends on a separate plugin toggle in Settings → Plugins → Auto DM new members. If you set the message but new members don't get it, check the toggle.

### Affiliate commission

`metadata.afl_percent` is read-only via the actor. Configure the affiliate program from Settings → Affiliates in the Skool UI. Members can opt-in from their account page.

## See also

- [Members](members.md) — for managing who joins your group
- [Recipes: Auto DM new members](../recipes/auto-dm-new-members.md)
- [Files](files.md) — for uploading the icon + cover
