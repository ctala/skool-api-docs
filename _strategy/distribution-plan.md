# Distribution Plan — Skool All-in-One API actor + doc-site

**Estado:** plan accionable, NO ejecutado aún (documentado 21-may-2026, retomar en sesión dedicada).
**Objetivo:** ser el **"GO TO"** para automatizar Skool — que el dev/founder que quiere automatizar Skool nos encuentre **donde sea que esté**, no solo en Google. El SEO + contenido ya están montados; falta awareness activa.

---

## Base de partida (21-may-2026)

- **Google = 43%** del tráfico del actor (SEO ya funciona como canal #1).
- **claude.ai** en referrers → citación por LLMs ya ocurre.
- **n8n.io** en referrers → 1 template publicado ([Auto-approve GPT-4o](https://n8n.io/workflows/14392-auto-approve-skool-community-members-with-gpt-4o-ai-screening/)) ya trae usuarios.
- MRR real, ~12 paying users, margin 98.79% (nicho rentable con pocos clientes).
- Doc-site: 19 integraciones + 13 recipes + pillar `skool api` + `llms.txt` + indexación (GSC/Bing/IndexNow).
- **1 actor único:** `cristiantala/skool-all-in-one-api`. NO publicar `skool-js` (moat).

---

## Canales priorizados (para la próxima sesión)

### 1. n8n Template Library — ALTO ROI (n8n.io ya es referrer)
Cada template publicado = una página en n8n.io (alto DA) con link a la doc + actor. Ya validado con 1 template.
- **Acción:** publicar 3-6 templates más, derivados de los recipes existentes. Reusar el patrón del template ya publicado.
- **Candidatos** (de `recipes/`):
  - Review & batch-approve waitlist (human-in-the-loop)
  - Reply to unanswered posts (LLM + Telegram approval)
  - Auto-DM new members
  - Event reminders → WhatsApp/Telegram (el flujo W-10 de eventos)
  - Newsletter → Skool post
  - Community analytics → NocoDB
- **Por template:** workflow JSON sanitizado (placeholders, sin credenciales — usar el checklist de sanitización) + descripción SEO + link a la recipe/doc + UTM `utm_campaign=n8n-template-{slug}`.
- **Esfuerzo:** ~30-45 min/template (exportar + sanitizar + describir + submit). Submit manual en n8n.io.
- **Empezar por:** batch-approve + reply-unanswered + auto-DM (los 3 de mayor uso).

### 2. Apify Store optimization — quick win de conversión
El actor en Apify Store rankea en Google (`skool apify`) + en la búsqueda interna de Apify, y es el destino final del funnel.
- **Acción:** README del actor optimizado (keywords `skool api`/`skool automation`, ejemplos copy-paste, categorías correctas, badges). Apuntar a "Actor of the week".
- **Esfuerzo:** 1-2 h. Alto impacto en conversión visita→run.

### 3. dev.to syndication — bajo esfuerzo (contenido ya existe)
Ya hay 3 posts EN (17-may). Syndicar las páginas nuevas de mayor valor con `canonical` apuntando a la doc (no duplicate content).
- **Candidatos:** pillar `skool api`, `skool-claude-code`, `export-skool-members`, recipe batch-approve.
- **Stack:** `reference_devto_api` (token + endpoint, header `api-key:`). ctala (ES) + cristiantalasanchez (EN).
- **Regla:** `canonical_url` siempre a `ctala.github.io/skool-api-docs/...`.

### 4. Product Hunt launch — alto impacto puntual (sesión dedicada)
- **Qué:** el actor como "The unofficial Skool API — automate your community with any AI agent". Apela a la ola de agentes.
- **Assets:** tagline, descripción, 3-5 screenshots/GIF (ej. Claude Code aprobando miembros en terminal), primer comment del maker, thumbnail.
- **Timing:** mar-jue, 12:01am PST. Pre-armar lista de upvoters (red Cristian + CAR + comunidades n8n/Apify).
- **Esfuerzo:** 1 sesión prep + día de launch. Owner: Cristian (cuenta PH + red).

### 5. Comunidades donde están los devs/founders de Skool — ongoing
Aportar valor primero, link cuando es relevante. NO spam.
- **Reddit:** r/Skool (si existe), r/nocode, r/SaaS, r/Entrepreneur, r/AI_Agents — responder "cómo automatizo Skool".
- **Indie Hackers:** post del journey ("built the unofficial Skool API, $X MRR, nicho sin competencia").
- **Skool communities de agencies/creators** (Skool Games, agency owners) — justo quienes NECESITAN automatizar Skool.
- **Discord/Slack** de n8n, Apify, MCP, AI-agents.
- **Owner:** Cristian (voz auténtica) o Nyx con HITL.

### 6. Directorios / awesome-lists / backlinks
- MCP directories (el actor como MCP tool), `awesome-mcp-servers`, `awesome-skool` (si existe), AlternativeTo, SaaS/API directories.
- Backlinks de calidad → sube la autoridad de dominio del doc-site → mejor ranking del pillar.

### 7. LinkedIn de Cristian (43K) — oportunista
- Post cuando haya ángulo (caso, milestone). **Ojo:** audiencia de Cristian = founders LATAM/ES, no devs globales → ángulo founder ("automaticé mi comunidad Skool con IA, así") más que técnico. No forzar.

---

## Orden recomendado para la próxima sesión
1. **n8n templates** (3 top: batch-approve, reply-unanswered, auto-DM) — ROI directo.
2. **Apify Store README** — quick win de conversión.
3. **dev.to syndication** (2-3 páginas) — contenido ya existe.
4. **Product Hunt prep** — sesión dedicada.
5. **Comunidades** — arrancar con 1-2, ongoing.

## Medición
- `utm_campaign` por canal en todos los links al actor → atribución de runs en Apify Insights (ya muestra referrers n8n.io / claude.ai).
- KPI: runs del actor (no pageviews) + nuevos paying users. Revisar Apify Insights mensual.

## No hacer
- Publicar `skool-js` en npm (mata el moat — ver memory `feedback-no-publicar-skool-js`).
- Spam en comunidades (aportar valor primero).
- Potenciar el actor `community-scraper` (caducado).
