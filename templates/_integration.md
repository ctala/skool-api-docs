---
# ===========================================================================
# TEMPLATE CANÓNICO — Páginas de integración Skool + [Tool]
# ===========================================================================
# Instrucciones de uso:
#   1. Copia este archivo a integrations/skool-{tool-slug}.md
#   2. Reemplaza TODOS los {placeholders} (búsqueda global con grep/{tool}).
#   3. Elige la variante estructural correcta (AI agent vs automation tool).
#   4. Ejecuta scripts/check-liquid.sh antes de hacer commit.
#   5. Sigue el playbook completo en templates/_integration-playbook.md.
# ===========================================================================

title: "Skool + {Tool} — {One-line benefit} ({Year})"
description: "Connect Skool to {Tool}. {2nd key capability}. {3rd key capability}. {UTM-free — jekyll-seo-tag usa esto para meta description y OG}."
slug: /integrations/skool-{tool-slug}
type: integration
primary_keyword: "skool {tool-slug}"
search_volume_monthly: {N}           # número entero, 0 si desconocido
funnel: A
playbook: integrations
last_updated: {YYYY-MM-DD}
canonical: https://ctala.github.io/skool-api-docs/integrations/skool-{tool-slug}/
render_with_liquid: false            # OBLIGATORIO si la página tiene {{ }} en code blocks
---


<!-- =========================================================
  SECCIÓN 1 — Quick reference / TL;DR for agents
  Propósito: responder en <30 segundos para crawlers y agentes.
  Regla: máximo 5 bullets. Siempre incluir cost y latency.
  ========================================================= -->

> **Quick reference (TL;DR for agents)**
> - **What this enables:** {1 frase — qué puede hacer {Tool} con Skool que antes no podía}.
> - **Method:** {Mecanismo técnico resumido — ej. "n8n HTTP Request node → POST JSON to Apify actor → Skool"}.
> - **Auth flow:** `auth:login` once → `cookies` string cached → reuse for ~3.5 days.
> - **Latency:** ~2s per action (cookies cached) / ~10s (`auth:login` cold start).
> - **Cost:** Apify pay-per-event (~$0.005–$0.01 per Skool action) + {Tool} on your existing plan.

<!-- =========================================================
  SECCIÓN 2 — Why {Tool} specifically? / Why connect Skool to {Tool}?
  USO POR VARIANTE:
    - AI agent (Claude, GPT, LangChain, Cursor…): usar "Why {Tool} specifically?"
      Explicar por qué ESTE modelo/framework es especialmente bueno con el actor
      (tool-use nativo, hint-reading, MCP support, etc.).
    - Automation tool (n8n, Make, Zapier, Python…): usar "Why connect Skool to {Tool}?"
      Explicar el gap: Skool no tiene API oficial, el actor lo resuelve,
      {Tool} puede llamarlo con un nodo HTTP sin SDK.
  ========================================================= -->

## Why {Tool} {specifically / for Skool}?

Skool has **no official API**. {1–2 oraciones explicando el problema concreto que tiene el lector de {Tool} hoy sin el actor}.

The [Apify-hosted Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-{tool-slug}) wraps the entire Skool admin surface in a single HTTP endpoint. {1 oración específica sobre por qué {Tool} se beneficia especialmente — ej. tool-use nativo, HTTP node nativo, etc.}.

<!-- Para AI agents: añadir 2-3 bullets con razones específicas del modelo/framework -->
<!-- Para automation tools: omitir bullets, ir directo a la tabla de "What you can automate" -->


<!-- =========================================================
  SECCIÓN 3A — What you can automate (automation tools: n8n, Make, Zapier, Python)
  Omitir para AI agents — ellos usan la sección 3B de integration paths.
  ========================================================= -->

## What you can automate

| Workflow | {Tool} component | Skool action | Recipe |
|---|---|---|---|
| Auto-approve new members | {Trigger} → {Logic} → HTTP | `members:pending` → `members:approve` | [Auto-approve members](../recipes/auto-approve-members-n8n.md) |
| Reply to unanswered posts | Schedule → flow | `posts:filter` → LLM → `posts:createComment` | [Reply unanswered](../recipes/reply-unanswered-posts.md) |
| Mirror newsletter to community | {Newsletter trigger} | `posts:create` | [Newsletter to Skool](../recipes/newsletter-to-skool-post.md) |
| Welcome DM new members | Webhook trigger | `groups:setAutoDM` | [Auto DM](../recipes/auto-dm-new-members.md) |
| Publish course from markdown | File trigger | `classroom:createCourse` + `classroom:setBody` | [Publish course](../recipes/publish-course-from-markdown.md) |
| Daily community health report | Schedule | `members:list` → `posts:list` → notify | — |

<!-- Ajusta la tabla: quita filas que no aplican, añade las que sí. -->


<!-- =========================================================
  SECCIÓN 3B — Integration paths (AI agents: Claude, GPT, LangChain, OpenCode…)
  Omitir para automation tools — ellos usan la sección 3A + setup step-by-step.
  Regla: máximo 3 paths. Ordenados de menor a mayor complejidad.
  ========================================================= -->

## Integration paths

<!-- OPCIÓN A — Path 1/2/3 independientes con subtítulo propio -->

### Path 1 — {Nombre descriptivo, ej. "Function calling / tool-use"}

{Código o configuración del path 1 con explicación mínima.}

```python
# {comentario explicativo}
# ... código del path 1
```

{1–2 oraciones de lo que hace el agente en este path y por qué funciona.}

### Path 2 — {Nombre descriptivo, ej. "MCP server (Claude Desktop / Cursor)"}

{Código o configuración del path 2.}

```json
{
  "note": "Si este bloque tiene {{ }}, el frontmatter tiene render_with_liquid: false"
}
```

### Path 3 — {Nombre descriptivo, ej. "Drop-in Skill / plugin"}

{Código o instrucciones del path 3.}


<!-- =========================================================
  SECCIÓN 4 — Architecture / How the connection works
  Para automation tools: diagrama ASCII del flujo {Tool} → Apify → Skool.
  Para AI agents: este diagrama puede ir dentro de cada path o como sección separada.
  Incluir siempre si el lector necesita visualizar el flujo completo.
  ========================================================= -->

## How the connection works

```
{Tool}                             Apify                         Skool
──────                             ─────                         ─────
[trigger / agent call]
        │
        ▼
[HTTP call ────────POST JSON──────→ run-sync-get-dataset-items ──→ api.skool.com]
{ action, cookies, groupSlug, ... }                               (cookies + WAF + buildId
        │                                   │                      handled by actor)
        ◄──────── { success: true, data: ... } ◄────────────────────┘
```

Every Skool operation = one HTTP POST. No SDK needed. The actor handles Playwright login (when needed), WAF token rotation, and Skool buildId changes.


<!-- =========================================================
  SECCIÓN 5 — Setup step-by-step (automation tools)
  Para AI agents: este bloque puede ser más corto o ir integrado en los paths.
  Siempre incluir el paso de auth:login con el curl canónico.
  ========================================================= -->

## Setup — 5 minutes

### 1. Get your Apify API token

Sign up at [apify.com](https://apify.com) — free tier covers most communities. Token from [console.apify.com/account/integrations](https://console.apify.com/account/integrations).

### 2. {Tool}-specific setup

{Pasos concretos de configuración en {Tool}: credentials store, environment variables, nodo HTTP, etc.}

### 3. Get your Skool cookies (one-time, valid ~3.5 days)

Run this once and store the returned `cookies` value in {Tool}'s credentials / env:

```bash
curl -X POST \
  "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=YOUR_APIFY_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "action": "auth:login",
    "email": "admin@yourcommunity.com",
    "password": "your-skool-password",
    "groupSlug": "your-community-slug"
  }'
```

The returned `cookies` string is valid for ~3.5 days. After that, re-run `auth:login` and store the new value.


<!-- =========================================================
  SECCIÓN 6 — Example: {the most compelling use case for {Tool}}
  Una sola receta representativa, código completo y funcional.
  Objetivo: que el lector pueda copiar-pegar y que funcione.
  Título siempre: "Example — {nombre del caso}"
  ========================================================= -->

## Example — {nombre del caso de uso más representativo}

{Contexto en 1 oración: qué hace el ejemplo y por qué es el más útil para usuarios de {Tool}.}

```{language}
# {comentario del paso 1}
# ... código completo y funcional
# {comentario del paso 2}
# ... continúa
```

{1–2 oraciones después del código: qué produce, costo estimado, frecuencia típica de uso.}


<!-- =========================================================
  SECCIÓN 7 — Production gotchas
  4–6 bullets. Siempre incluir los 3 canónicos (x402, WAF_EXPIRED, parentId).
  Añadir 1–2 específicos de {Tool} si los hay.
  Nunca más de 6 bullets — si hay más, moverlos a error-handling docs.
  ========================================================= -->

## Production gotchas

- **`x402-payment-required` on every call:** Not a billing issue — it's a stale `UNDER_MAINTENANCE` flag from Apify's heuristic. Open the [actor page](https://apify.com/cristiantala/skool-all-in-one-api) in Apify Console once to reset. Details in [error handling](../docs/error-handling.md).
- **Cookies expiring silently:** When `errorCode: "WAF_EXPIRED"` appears, re-run `auth:login` and store new cookies. Design your {Tool} flow to branch on this error code.
- **`parentId` for comment replies:** Top-level comment → `rootId == parentId == postId`. Reply to a comment → `rootId == postId`, `parentId == commentId`. Mixing these is the most common silent bug.
- **Rate limit ~25 writes/min:** Skool's hard limit. The actor queues internally — don't add your own retry loop on top.
- {Gotcha específico de {Tool} si aplica — ej. "n8n: typeVersion must be 2 for HTTP Request node in n8n ≥1.x".}
- {Gotcha específico de {Tool} si aplica — ej. "Cursor: MCP tool timeout defaults to 10s; configure ≥30s for auth:login".}


<!-- =========================================================
  SECCIÓN 8 — See also
  Internal links obligatorios: siempre los 4 canónicos.
  Añadir 1–2 específicos según el tipo de integración.
  ========================================================= -->

## See also

- [Skool for AI agents](../for/ai-agents.md) — full pattern library + function-calling specs
- [Actions reference](../docs/actions.md) — complete list of actions and params
- [Authentication](../docs/authentication.md) — cookie lifecycle, rotation patterns
- [Error handling](../docs/error-handling.md) — x402, WAF_EXPIRED, rate limits
- [All integrations →](index.md)
<!-- Añadir 1–2 links específicos según variante:
     AI agents: [Skool MCP server](skool-mcp-server.md) + [Skool + Claude](skool-claude.md) o [Skool + GPT](skool-gpt.md)
     Automation tools: links a recipes relevantes al tool
-->


<!-- =========================================================
  SECCIÓN 9 — CTA final
  Reglas:
  - Título H2: "Start automating Skool today" (automation) o
                "Plug Skool into {Tool} today" (AI agent).
  - Link principal: Apify actor con UTM campaign=skool-{tool-slug}.
  - 3 bullets de valor debajo del link (siempre los mismos 3: cost, surface, production-ready).
  - Italic footer: referral link Skool para nuevas comunidades.
  - JSON-LD: bloque <script> inmediatamente después del separador ---.
  ========================================================= -->

---

## {Start automating Skool today / Plug Skool into {Tool} today}

[**→ Use the Skool All-in-One API actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-{tool-slug})

- Pay-per-event (~$0.005–$0.01 per Skool action, ~$1.50/mo typical)
- Read AND write — full API surface (posts, comments, members, classroom, files, Auto DM)
- Battle-tested in production

*No Skool community yet? [Launch one in 10 minutes](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "TechArticle",
  "headline": "Skool + {Tool} — {One-line benefit}",
  "description": "{Mismo texto que el campo description del frontmatter}",
  "datePublished": "{YYYY-MM-DD}",
  "dateModified": "{YYYY-MM-DD}",
  "author": {
    "@type": "Person",
    "name": "Cristian Tala",
    "url": "https://cristiantala.com"
  },
  "publisher": {
    "@type": "Person",
    "name": "Cristian Tala",
    "url": "https://cristiantala.com"
  },
  "mainEntityOfPage": "https://ctala.github.io/skool-api-docs/integrations/skool-{tool-slug}/"
}
</script>
