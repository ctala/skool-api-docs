---
title: "{Title — short, action-oriented, target keyword in front}"
description: "{1-sentence value prop, ≤155 chars, with the keyword.}"
slug: /recipes/{kebab-case-slug}
type: recipe
primary_keyword: "{target keyword}"
search_volume_monthly: {N or null}
funnel: A
playbook: templates
last_updated: 2026-05-19
canonical: https://skool-api.cristiantala.com/recipes/{kebab-case-slug}/
render_with_liquid: false
---


> **Quick reference (TL;DR for agents)**
> - **Goal:** {1 sentence what this does}
> - **Stack:** {n8n / Make / Python / Claude / cURL}
> - **Actor actions used:** `auth:login` → `{namespace:action}` → ...
> - **Setup time:** ~{X} min
> - **Ongoing cost:** ~${Y}/mo on Apify pay-per-event

## What this recipe does

{2-3 sentences. State the user problem first, then the solution.}

## Prerequisites

- Apify token ([get one](https://console.apify.com/account/integrations?fpr=cristian))
- Skool admin credentials for the community you're automating
- {tool-specific: n8n instance, Make.com account, Python 3.10+, etc.}

## Step 1 — {first concrete step}

```bash
{copy-paste-ready command or JSON payload}
```

{What this does, in 1-2 lines.}

## Step 2 — {second step}

```json
{
  "action": "...",
  "cookies": "{{ $cookies }}",
  "groupSlug": "your-community",
  "params": { ... }
}
```

{Expected response shape:}

```json
{
  "success": true,
  ...
}
```

## Step 3 — {third step}

{...}

## Production gotchas

- **{Common pitfall 1}**: {Symptom → cause → fix in one line.}
- **{Common pitfall 2}**: {...}

## Full workflow JSON / code

<details>
<summary>Click to expand the complete {n8n / Python / cURL} flow</summary>

```json
{
  ... entire flow JSON / code
}
```

</details>

## See also

- [{Related recipe 1}](../recipes/{slug}.md)
- [{Related doc}](../docs/{slug}.md)
- [Action reference](../docs/actions.md)

---

## Use this in production — no setup

The hardest part of building Skool automation isn't the API logic — it's the auth (cookies expire every ~3.5 days, WAF token rotation, weekly Skool buildId changes). The **[Skool All-in-One API actor on Apify](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign={kebab-case-slug}&fpr=cristian)** handles all of that.

- Pay-per-event pricing (~$1.50/mo for typical communities)
- One JSON POST per action — works from any HTTP client
- Built and battle-tested in production

[**→ Start using it on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign={kebab-case-slug}&fpr=cristian)

*New to Skool? [Launch your community here](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<!-- JSON-LD schema for search engines and AI agents -->
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "HowTo",
  "name": "{Title}",
  "description": "{description}",
  "totalTime": "PT{X}M",
  "tool": [
    {"@type": "HowToTool", "name": "Apify"},
    {"@type": "HowToTool", "name": "{n8n / Make / etc.}"}
  ],
  "step": [
    {"@type": "HowToStep", "name": "Step 1", "text": "..."},
    {"@type": "HowToStep", "name": "Step 2", "text": "..."},
    {"@type": "HowToStep", "name": "Step 3", "text": "..."}
  ]
}
</script>
