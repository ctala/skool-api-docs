# Integration Page Playbook — skool-api-docs

Playbook reproducible para crear páginas de integración "Skool + [Tool]".
Aplica a: Claude Code, OpenCode, OpenClaw, Hermes, Cursor, Cline, Gemini, CrewAI, y cualquier agente o framework futuro.
Template canónico: `templates/_integration.md`.

---

## 0. Antes de empezar — validar que vale la pena

Cada página nueva cuesta ~2-3 horas de trabajo de calidad. No publicar si no se cumplen al menos 2 de estos 3 criterios:

| Criterio | Señal concreta |
|---|---|
| Hay demanda de búsqueda | Keyword `skool {tool}` tiene volumen > 0 en Ahrefs/GSC, o el tool tiene >10K usuarios activos |
| Hay relevancia técnica real | El tool puede llamar un HTTP endpoint, ejecutar tool-use, o configurar MCP — hay código real que mostrar |
| Tiene funnel A claro | Un developer/power-user de {Tool} que lee la página tiene ruta directa al actor en Apify |

Si la página no tiene código real ejecutable (solo marketing), no publicar — pierde autoridad técnica.

---

## 1. Determinar la variante estructural

Antes de copiar el template, clasificar {Tool} en una de dos variantes:

### Variante A — AI agent / LLM framework
Aplica a: Claude, GPT, Gemini, LangChain, LlamaIndex, CrewAI, OpenCode, OpenClaw, Hermes, Cursor, Cline, Continue, Claude Code.

Estructura característica:
- Sección 2: "Why {Tool} specifically?" — enfocada en capacidades del modelo (tool-use, hint-reading, MCP, function calling)
- Sección 3B: "Integration paths" con 2-3 paths ordenados por complejidad (no tabla de workflows)
- Sección 5 setup: más corta, integrada en los paths o como anexo
- Sección 6 example: un agent loop completo, no un workflow step-by-step

### Variante B — Automation tool / workflow builder
Aplica a: n8n, Make.com, Zapier, Python, Ruby, Node.js, PHP, webhooks, Postman, REST clients.

Estructura característica:
- Sección 2: "Why connect Skool to {Tool}?" — enfocada en el gap (Skool sin API oficial vs lo que {Tool} puede hacer)
- Sección 3A: tabla "What you can automate" con workflows + links a recipes
- Sección 5 setup: paso a paso numerado con screenshots o JSON exportable si aplica
- Sección 6 example: workflow end-to-end con el caso de uso más popular

---

## 2. Placeholders a rellenar — checklist

Antes de publicar, verificar que no queda ningún placeholder `{...}` sin reemplazar.

```
Frontmatter:
[ ] title          — "Skool + {Tool} — {One-line benefit} ({Year})"
[ ] description    — 150-160 chars, sin {{ }}, sin emojis, termina con punto
[ ] slug           — /integrations/skool-{tool-slug}  (lowercase, hyphens)
[ ] primary_keyword — "skool {tool-slug}" en lowercase
[ ] search_volume_monthly — número entero (0 si no se sabe)
[ ] last_updated   — fecha ISO de hoy (YYYY-MM-DD)
[ ] canonical      — URL del sitio publicado (ctala.github.io/skool-api-docs/...)
[ ] render_with_liquid — agregar `render_with_liquid: false` si la página tiene {{ }} en code blocks

Secciones:
[ ] Quick reference — 5 bullets, cost y latency incluidos
[ ] Sección 2 "Why" — enfocada en el tipo de herramienta (variante A o B)
[ ] Sección 3 — tabla de workflows (B) o paths (A), con código real y funcional
[ ] Sección 4 architecture — diagrama ASCII (puede omitirse si está redundante con paths)
[ ] Sección 5 setup — auth:login curl canónico siempre presente
[ ] Sección 6 example — código completo copy-pasteable
[ ] Sección 7 gotchas — 3 canónicos + 1-2 específicos del tool
[ ] Sección 8 see also — 4 links canónicos + 1-2 específicos
[ ] Action surface — tabla agrupada de las acciones (6 categorías) + link a docs/actions.md (va después de Example, antes de gotchas)
[ ] Hand this to your agent — snippet del método del tool (MCP config / tool wrapper) + link al primer canónico for/ai-agents.md (va después de gotchas, antes de see also)
[ ] Sección 9 CTA — UTM campaign=skool-{tool-slug}, 3 bullets de valor, referral footer
[ ] JSON-LD — headline + description + datePublished + dateModified + author + mainEntityOfPage

UTMs:
[ ] Todos los links al actor tienen ?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-{tool-slug}
[ ] Referral link Skool: https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63
```

---

## 3. Reglas de contenido técnico

**R1 — Código funcional o no va.**
Todo code block debe ser ejecutable tal como está (con las variables de entorno declaradas). Si no está probado, marcarlo con un comentario `# untested — verify before production`.

**R2 — Liquid check obligatorio.**
Si la página tiene `{{ }}` en code blocks (n8n expressions, Make.com, Handlebars, cualquier framework), agregar `render_with_liquid: false` en frontmatter Y ejecutar:
```bash
cd /path/to/skool-api-docs && bash scripts/check-liquid.sh
```
El script hace exit 1 si detecta patrones problemáticos. No hacer commit con exit 1.

**R3 — Gotchas canónicos siempre.**
Estos 3 gotchas van en TODAS las páginas sin excepción:
1. `x402-payment-required` — no es billing, es flag UNDER_MAINTENANCE
2. `WAF_EXPIRED` — re-run auth:login y rotar cookies
3. `parentId` para comment replies — el bug silencioso más común

**R4 — Internal links, no keyword stuffing.**
El actor se linkea máximo 3 veces por página (Quick reference + Why section + CTA final). No repetir el link en cada párrafo.

**R5 — UTM en todos los links al actor.**
Sin excepción. El pattern es siempre: `?utm_source=skool-api-docs&utm_medium=integration&utm_campaign=skool-{tool-slug}`.

**R6 — JSON-LD completo.**
La página del template original tenía un JSON-LD mínimo (solo headline + datePublished + author). El estándar requiere: headline, description, datePublished, dateModified, author (con url), publisher, mainEntityOfPage.

**R7 — Action surface + Hand-to-agent, sin duplicar el primer.**
Toda página de AI agent incluye dos secciones nuevas (ver el piloto `integrations/skool-claude-code.md`):
1. **Full action surface** — tabla de las acciones agrupadas en 6 categorías (posts / members / events / classroom / files & groups / system), 1 línea por acción, + link a `docs/actions.md` para los params. Es referencia + citation bait para LLMs.
2. **Hand this to your agent** — el snippet del MÉTODO del tool (MCP config para tools MCP-native; tool wrapper Python para frameworks) + link a `for/ai-agents.md`.

`for/ai-agents.md` es el **primer canónico** (Claude tool-use / OpenAI function-calling / MCP / LangChain snippets + agent loop). **NO duplicar el primer completo** en cada página — enlazarlo. Lo único por página (≥40% del contenido): Why, Setup/config, Example, gotchas específicos del tool. Así la familia de páginas refuerza topical authority hacia el pillar sin caer en duplicate content.

**R8 — Links a la versión web indexable.**
Internal links siempre como **paths relativos** (`skool-mcp.md`, `../docs/actions.md`) — Jekyll los resuelve a URLs `https://ctala.github.io/skool-api-docs/...` que los buscadores rastrean e indexan. NUNCA linkear referencias de contenido a `github.com/blob/...` (no es la URL canónica indexable). `raw.githubusercontent.com` SOLO para descargas (instalar SKILL/scripts). `canonical` y `mainEntityOfPage` siempre a `ctala.github.io`.

---

## 4. Pasos de publicación

### Paso 1 — Crear el archivo
```bash
cp /path/to/skool-api-docs/templates/_integration.md \
   /path/to/skool-api-docs/integrations/skool-{tool-slug}.md
```

### Paso 2 — Completar los placeholders
Editar `integrations/skool-{tool-slug}.md`:
- Usar la checklist de la sección 2 de este playbook
- Revisar que el código sea correcto para la versión actual del actor (ver `docs/actions.md`)
- Confirmar los gotchas específicos del tool (si existen, documentarlos)

### Paso 3 — Verificar Liquid
```bash
cd /path/to/skool-api-docs
bash scripts/check-liquid.sh
```
Si hay issues: o agregar `render_with_liquid: false` en frontmatter o envolver el bloque con `{% raw %}...{% endraw %}`.

### Paso 4 — Registrar en el hub de integraciones
Editar `integrations/index.md` y agregar una fila en la tabla "All integrations":
```markdown
| **{Tool}** | {Best for — 4-6 palabras} | [Skool + {Tool}](skool-{tool-slug}.md) |
```
Ubicar la fila en el grupo correcto (AI agents juntos, automation tools juntos).

### Paso 5 — Verificar internal links desde otras páginas
Revisar si hay páginas existentes que deberían linkear a la nueva:
```bash
# Buscar menciones del tool que no tienen link
grep -r "{tool}" /path/to/skool-api-docs --include="*.md" -l
```
En particular: `for/ai-agents.md`, `docs/agents.md`, y `integrations/skool-mcp.md` suelen ser candidatos para páginas de AI agents.

### Paso 6 — Commit
```bash
cd /path/to/skool-api-docs
git add integrations/skool-{tool-slug}.md integrations/index.md
git commit -m "feat(integrations): add Skool + {Tool} integration page"
git push origin main
```
GitHub Pages hace deploy automático en ~2 minutos.

### Paso 7 — IndexNow ping (Bing/Yandex/Naver/Seznam)
Después del deploy, notificar a los motores de búsqueda alternativos.
La key de IndexNow para `ctala.github.io` está documentada en `reference_indexnow_keys.md` (memory del repo Estrategias).

```bash
# Ejemplo de ping (reemplazar KEY y URL)
curl -X POST "https://api.indexnow.org/indexnow" \
  -H "Content-Type: application/json" \
  -d '{
    "host": "ctala.github.io",
    "key": "{KEY}",
    "keyLocation": "https://ctala.github.io/{KEY}.txt",
    "urlList": [
      "https://ctala.github.io/skool-api-docs/integrations/skool-{tool-slug}/"
    ]
  }'
```

### Paso 8 — GSC sitemap resubmit (opcional, si hay cambios masivos)
Para una sola página nueva el sitemap se actualiza solo con `jekyll-sitemap`. Solo necesario si se publica un batch de 3+ páginas:
```bash
python3 .claude/skills/elhda-new-episode/scripts/gsc_resubmit_sitemap.py \
  --site sc-domain:ctala.github.io
```
(Script vive en el repo Estrategias, no en skool-api-docs.)

---

## 5. Plan de distribución / syndication por página nueva

Cada página nueva tiene canonical en `ctala.github.io/skool-api-docs/integrations/skool-{tool-slug}/`. La distribución amplifica sin crear duplicate content.

### Canal 1 — dev.to ES (ctala) — Funnel A prioritario

Publicar una versión en español del core de la página como post independiente en dev.to ES.
- Canonical: apuntar a la URL de `ctala.github.io/skool-api-docs` (no a sí mismo en dev.to)
- Tags: `skool`, `automatizacion`, `ia`, `{tool en español o inglés}`
- Título: "Cómo conectar Skool con {Tool} (sin API oficial)" o "Skool + {Tool}: automatiza tu comunidad"
- El post incluye el código del ejemplo principal + CTA al actor con UTM `utm_medium=devto-es`
- API: `reference_devto_api.md` en memoria del repo Estrategias, cuenta `ctala`

```bash
# Draft en dev.to ES con canonical apuntando al sitio
# Ver reference_devto_api.md para token y endpoint
```

### Canal 2 — dev.to EN (cristiantalasanchez) — Funnel A secundario

Si el tool tiene audiencia global significativa (Claude, GPT, Cursor, LangChain: sí; tools nicho LATAM: no).
- Misma estructura que ES pero en inglés
- No duplicar: el post EN puede ser el mismo texto de la página canónica, con canonical apuntando a `ctala.github.io`
- Cuenta: `cristiantalasanchez`

### Canal 3 — GitHub cross-link desde recipes relevantes

Identificar si existe alguna recipe en `recipes/` que use el tool y agregarle un link a la nueva página de integración. Esto es internal linking dentro del mismo sitio + señal de autoridad de GitHub.

Ejemplo: si se publica `skool-opencode.md`, revisar si `recipes/reply-unanswered-posts.md` o `recipes/publish-course-from-markdown.md` mencionan "any AI agent" — y agregar un link natural a la nueva página.

### Canal 4 — LinkedIn post de Cristian (opcional, solo para tools con gran audiencia)

Aplica para: Claude Code, Cursor, Cline, n8n, Make, LangChain. No aplica para tools de nicho técnico muy estrecho.
- Formato: post corto (300-500 chars), founder-a-founder, cifra concreta (ej. "$0.01 por acción Skool, sin SDK")
- CTA: link a la página de integración (UTM `utm_medium=linkedin`)
- No usar el exit ni el $23M — este es contenido técnico, no storytelling de founder
- Coordinación: Brand Marketing Strategist para voz, Performance Marketing para UTM tracking

### Canal 5 — Cross-link desde `for/ai-agents.md` (para AI agent pages)

Para cualquier página de AI agent (Claude, GPT, LangChain, Cursor, Cline, etc.), agregar el link en `for/ai-agents.md` en la sección de integraciones o en la tabla de herramientas compatibles. Esta página ya tiene autoridad interna y es un hub de tráfico.

### Anti-patterns de distribución — no repetir

- No publicar en Medium con canonical a sí mismo en Medium — siempre canonical a `ctala.github.io`
- No publicar en dev.to el mismo texto que skool-api-docs sin canonical configurado — Google penaliza duplicate content
- No crear post de LinkedIn para cada página — solo tools con audiencia > 50K usuarios activos merita el effort
- No syndication en Hashnode — canal deprecated desde 17-may-2026 (killed free API)

---

## 6. Registro de páginas publicadas

Al publicar cada página nueva, actualizar este registro:

| Tool | Archivo | Variante | Fecha | dev.to ES | dev.to EN | IndexNow |
|---|---|---|---|---|---|---|
| Claude | `skool-claude.md` | A (AI agent) | 2026-05-19 | — | — | — |
| MCP | `skool-mcp.md` | A (AI agent) | 2026-05-19 | — | — | — |
| GPT | `skool-gpt.md` | A (AI agent) | 2026-05-19 | — | — | — |
| LangChain | `skool-langchain.md` | A (AI agent) | 2026-05-19 | — | — | — |
| n8n | `skool-n8n.md` | B (automation) | 2026-05-19 | — | — | — |
| Make.com | `skool-make-com.md` | B (automation) | 2026-05-19 | — | — | — |
| Zapier | `skool-zapier.md` | B (automation) | 2026-05-19 | — | — | — |
| Python | `skool-python.md` | B (automation) | 2026-05-19 | — | — | — |
| Webhook | `skool-webhook.md` | B (automation) | 2026-05-19 | — | — | — |
| MCP Server | `skool-mcp-server.md` | A/B (híbrido) | 2026-05-19 | — | — | — |

Páginas candidatas (aún no publicadas):

| Tool | Variante | Keyword | Vol. estimado | Prioridad |
|---|---|---|---|---|
| Claude Code | A (AI agent) | `skool claude code` | bajo, nicho alto intent | Alta |
| Cursor | A (AI agent) | `skool cursor mcp` | bajo, creciendo | Alta |
| Cline | A (AI agent) | `skool cline` | muy bajo, early adopters | Media |
| OpenCode | A (AI agent) | `skool opencode` | muy bajo, nuevo | Media |
| Hermes | A (AI agent) | `skool hermes agent` | muy bajo, nicho | Baja |
| CrewAI | A (AI agent) | `skool crewai` | bajo | Media |
| Gemini | A (AI agent) | `skool gemini` | bajo-medio | Alta |
| OpenAI Assistants | A (AI agent) | `skool assistants api` | bajo | Media |
| Node.js | B (automation) | `skool node.js api` | muy bajo | Baja |

---

## 7. Notas sobre el sitio Jekyll

- `_config.yml` excluye `templates/` del build — este playbook NO se publica en `ctala.github.io`.
- `jekyll-seo-tag` toma `title`, `description`, y `canonical` del frontmatter para generar `<title>`, `<meta name="description">`, y `<link rel="canonical">` automáticamente.
- `jekyll-sitemap` genera `sitemap.xml` automáticamente a partir de todos los `.md` publicados.
- `permalink: pretty` en `_config.yml` convierte `integrations/skool-claude.md` en `/integrations/skool-claude/index.html` — las URLs terminan en `/`.
- El tema `jekyll-theme-cayman` no requiere frontmatter `layout` en páginas de `integrations/` porque está en los `defaults` de `_config.yml`.
- Si una página tiene `{{ }}` y no tiene `render_with_liquid: false`, Jekyll puede fallar silenciosamente en GitHub Pages. Usar siempre `check-liquid.sh` antes de push.
