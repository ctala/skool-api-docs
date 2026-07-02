# Skool Actor — Claude Code plugin

Read and write to any Skool community straight from Claude Code. Approve pending members, reply to posts, publish classroom courses from Markdown, update your Auto DM — all through one battle-tested API call per action, no browser automation, no Playwright, no weekly `buildId` chasing.

Backed by the [Apify-hosted Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=cc-plugin&utm_medium=readme&utm_campaign=skool-actor&fpr=cristian) (pay-per-event, ~$0.005–$0.01 per call).

## Install

```shell
/plugin marketplace add ctala/skool-api-docs
/plugin install skool-actor@skool-api
```

Then reload:

```shell
/reload-plugins
```

## Setup (one time)

Store these in a local `.env` (never commit them):

```bash
APIFY_TOKEN=apify_api_...          # from console.apify.com/account/integrations
SKOOL_EMAIL=admin@example.com      # your Skool admin login
SKOOL_PASSWORD=...
SKOOL_GROUP_SLUG=your-community     # the part after skool.com/
SKOOL_COOKIES=                     # auto-populated after first auth:login (~3.5 day TTL)
```

Free Apify tier is enough to start.

## What you can say

- "List the pending members in my Skool community and approve the ones who filled the LinkedIn field"
- "Reply to every unanswered post from this week"
- "Publish this folder of Markdown files as a Skool classroom course"
- "Update the Auto DM new members get"

The skill is model-invoked — Claude reaches for it automatically when your request involves Skool.

## Why the API instead of scraping Skool directly

Pointing your agent's browser/fetch tool at `skool.com` means loading the full rendered page (hundreds of KB of HTML/JS) into context on every read — expensive in tokens and brittle when Skool ships. This skill returns clean structured JSON in a single call. Same task, a fraction of the context.

## Docs

Full setup, example session, and the full action surface: <https://skool-api.cristiantala.com/integrations/skool-claude-code/>

Recipes and the rest of the reference docs: <https://skool-api.cristiantala.com>
