---
title: "Auto-DM new Skool members (set the welcome DM via API)"
description: "Set or update your Skool auto welcome DM programmatically with groups:setAutoDM — rotate offers and onboarding links without UI clicks."
slug: /recipes/auto-dm-new-members
type: recipe
funnel: A
section: Recipes
last_updated: 2026-07-12
render_with_liquid: false
---

# Auto DM new members

Send a personalized welcome DM the moment someone joins your Skool community. Skool has this feature built in — `groups:setAutoDM` lets you set/update the message programmatically (no UI clicks).

## What it does

When a new member joins (gets approved by you or auto-approved), Skool fires a DM from the group owner to that member with the message you configured. The DM appears as a real conversation start — replies go to the owner's inbox.

## The action

```json
{
  "action": "groups:setAutoDM",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "message": "👋 Welcome #NAME# to #GROUPNAME#!\n\nStart with the 'Empieza Aquí' course — 15 min that change how you use the community.\n\nQuestion: what's the #1 thing you want to fix in the next 30 days? Hit reply.\n\n— Cristian"
  }
}
```

| Token | Replaced with |
|---|---|
| `#NAME#` | Member's first name |
| `#GROUPNAME#` | Your community's display name |

## Constraints

- **300-character maximum** (Skool enforces this in the UI; the actor returns `INPUT_VALIDATION` if exceeded)
- **Plain text only** — newlines via `\n`, no markdown, no HTML
- The Auto DM **plugin must be enabled** in `Settings → Plugins → Auto DM new members` for the message to actually fire. Setting the message via the actor is independent of the toggle. If members don't get the DM, check the toggle.

## Crafting the message

This is a 300-char persuasive pitch — the most concentrated piece of copy in your community. Treat it accordingly.

### What works (from production communities)

- **Short, scannable**: 3-4 sentences max. Avoid walls of text.
- **One concrete next action**: "Start with X course" or "Reply with Y question" — never multi-step.
- **A question that triggers reply**: members who reply have ~3× retention vs silent ones. The DM thread becomes a relationship.
- **Personality, not corporate**: emojis OK if they're brand-coherent. Sound like a human.
- **First-name basis**: `#NAME#` token at the start.

### What doesn't work

- ❌ "Welcome to the community! We're so excited you joined! Be sure to check out…" — generic, no signal
- ❌ Long links the member has to click to find anything (DMs strip URL preview cards)
- ❌ Multiple CTAs ("read the rules, post intro, browse classroom, attend events") — paralysis

### Example: from CAR (Spanish, founders LATAM, 480+ members)

```
👋 Bienvenido #NAME# a #GROUPNAME#

Tu primer paso: el curso "🚀 Empieza Aquí" en classroom — 15 min que cambian cómo aprovechas la comunidad.

Pregunta: ¿cuál es el #1 problema que quieres resolver en tu startup este mes? Responde por acá.

— Cristian
```

(248 chars. One concrete action. One reply trigger.)

## Updating the message

`groups:setAutoDM` is idempotent — calling it again replaces the existing message. New joins after the call get the new message; previous DMs aren't touched.

If you A/B test messages (highly recommended), version them with a tag in your audit log:

```javascript
const messages = {
  v1: "...",
  v2: "...",
};
const ACTIVE = 'v2';

await call({ action: 'groups:setAutoDM', cookies, groupSlug, params: { message: messages[ACTIVE] } });
log({ event: 'auto_dm_set', version: ACTIVE, at: new Date() });
```

Track conversion: `% of new members who reply within 24h`. CAR's v2 (current) gets ~22% reply rate vs v1's 11%.

## When to update

- After publishing a new pillar course → update the DM to reference it
- After a big launch / rebrand → sync the DM tone
- Every 2-3 months → keep it fresh, prevent stagnation

## See also

- [Groups docs](../docs/groups.md)
- [Members docs](../docs/members.md) — for member lifecycle context
- [Recipe: Auto-approve members](auto-approve-members-n8n.md) — pair this with auto-approval for fully automated onboarding

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "HowTo",
  "name": "Auto-DM new Skool members with groups:setAutoDM",
  "description": "Set or update your Skool auto welcome DM programmatically with groups:setAutoDM, rotating offers and onboarding links without UI clicks.",
  "totalTime": "PT5M",
  "tool": [
    {"@type": "HowToTool", "name": "Apify"},
    {"@type": "HowToTool", "name": "Skool admin cookies"}
  ],
  "step": [
    {"@type": "HowToStep", "name": "Enable the Auto DM plugin", "text": "Turn on Settings, Plugins, Auto DM new members in Skool so the configured message actually fires when someone joins."},
    {"@type": "HowToStep", "name": "Set the message via groups:setAutoDM", "text": "Call groups:setAutoDM with a plain-text message up to 300 characters using the #NAME# and #GROUPNAME# tokens. Calling it again replaces the existing message."},
    {"@type": "HowToStep", "name": "Craft and iterate the copy", "text": "Write a short, scannable DM with one concrete next action and one reply-triggering question, then A/B test versions and track the 24h reply rate."}
  ]
}
</script>
