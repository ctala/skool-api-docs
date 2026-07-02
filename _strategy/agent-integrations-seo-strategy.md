# Agent Integrations — SEO Strategy

**Estado:** ejecutado 21-may-2026 (commit `5ce6bda`, 9 páginas Tier 1+2 live) — corregido 2-jul-2026, el header quedó desactualizado y generaba falsa sensación de trabajo pendiente
**Autor:** SEO Specialist
**Fecha:** 2026-05-21
**Scope:** familia de páginas "usar el Skool All-in-One API actor con [agente / CLI / framework de IA]"
**Funnel:** A (developer googlea integración → llega al doc → adopta el actor → MRR pay-per-event)

---

## 0. Contexto y tesis

El doc-site ya tiene un `playbook: integrations` maduro con páginas por **stack de automatización** (n8n, Make, Zapier, Webhooks, Python) y por **modalidad de IA** (Claude, GPT, LangChain, MCP, MCP Server). El patrón está probado: front matter con `primary_keyword` + `search_volume_monthly`, bloque `> Quick reference (TL;DR for agents)` arriba, paths numerados, tabla de patterns, gotchas, CTA al actor + ref link de Skool, JSON-LD `TechArticle`.

Lo que falta es una capa nueva: páginas por **agente/CLI/framework concreto** — el sustantivo que el developer escribe en Google. Hoy hay una página `skool-claude` (Anthropic API genérico) y `skool-mcp` (protocolo), pero NO hay páginas para los productos por nombre: **Claude Code, Cursor, Cline, Windsurf, OpenCode, Goose, Aider, Gemini CLI, CrewAI, LlamaIndex, AutoGen**, etc.

**La tesis SEO:** el volumen de búsqueda de marca de producto (`cursor mcp`, `claude code skill`, `goose mcp`) crece más rápido que el de protocolo abstracto (`skool mcp` = ~10/mes). El developer no busca "model context protocol skool" — busca "cómo conecto MI herramienta a X". Capturamos esa intención con una página por herramienta, todas convergiendo en el mismo actor.

**Realidad del volumen:** "skool + [agente]" es cola larga extrema. Casi nadie busca literalmente "skool cursor" hoy (Skool no tiene API oficial, el mercado es incipiente). El volumen real está en el **head term de la herramienta** (`cursor mcp server` ~miles/mes) donde competimos por una posición de nicho ("skool" como caso de uso), NO en el long-tail exacto "skool cursor" (~0). Por eso la estrategia NO es rankear #1 por "skool cursor" (trivial, sin tráfico) sino:

1. **Capturar el long-tail de intención específica** ("skool [tool] integration", "automate skool with [tool]") donde la competencia es CERO y basta existir para rankear.
2. **Ser citado por agentes IA** (SGE, Claude/Cursor/Perplexity con web access) cuando un developer le pregunta a SU agente "cómo conecto Skool a esto" — el agente lee nuestra página estructurada y recomienda el actor. Este es el canal de mayor upside dado que la audiencia ES gente que usa agentes.
3. **Topical authority**: una familia densa de páginas "skool + [cada herramienta]" le dice a Google que este dominio ES la autoridad de "integrar Skool con cualquier cosa", reforzando el ranking del hub y de las páginas de mayor volumen (`skool api`, `skool integration`).

---

## 1. Keyword research por candidato

Volúmenes estimados (US, mensual). Notación:
- **Head** = volumen del término de la herramienta + "mcp"/"skill"/"tool" (NO específico de Skool) — el océano donde nadamos.
- **Exact** = volumen del long-tail literal "skool [tool]" — casi siempre <10, pero conversión altísima y competencia nula.
- **KD** = dificultad para nuestro ángulo de nicho (rankear por el long-tail "skool [tool]"), no para el head term.

| # | Candidato | Keyword primario propuesto | Head vol (tool+mcp/skill) | Exact "skool [x]" | Intención | KD nicho | Señal de demanda (2026) |
|---|---|---|---|---|---|---|---|
| 1 | **Cursor** | `skool cursor` / `automate skool with cursor` | Alto (cursor mcp server = miles/mes) | ~0–10 | Transaccional/dev | Muy baja | MCP nativo, plugin store, `~/.cursor/mcp.json`. Producto de IA-coding más buscado |
| 2 | **Claude Code** | `skool claude code` / `claude code skool skill` | Alto (claude code skills = miles/mes; 1,000+ skills) | ~0–10 | Transaccional/dev | Muy baja | Skill system = ecosistema de extensión que más crece. Ya tenemos el Skill construido |
| 3 | **Cline** | `skool cline` / `cline skool mcp` | Medio-alto (cline mcp = cientos/mes) | ~0 | Transaccional/dev | Muy baja | Deepest native MCP, marketplace activo, VS Code |
| 4 | **Windsurf** | `skool windsurf` / `windsurf skool integration` | Medio-alto (windsurf mcp = cientos/mes) | ~0 | Transaccional/dev | Muy baja | Cascade MCP nativo, plugin store, `mcp_config.json` |
| 5 | **OpenCode** | `skool opencode` / `opencode skool mcp` | Medio (opencode mcp creciendo fuerte) | ~0 | Transaccional/dev | Muy baja | #1 HN mar-2026, 120K stars, 5M devs/mes, alternativa OSS top a Claude Code |
| 6 | **Gemini CLI** | `skool gemini cli` / `automate skool with gemini cli` | Medio (gemini cli mcp = cientos/mes) | ~0 | Transaccional/dev | Muy baja | MCP nativo + FastMCP, respaldo Google, settings.json |
| 7 | **Goose** | `skool goose` / `goose mcp skool` | Medio (goose mcp = cientos/mes) | ~0 | Transaccional/dev | Muy baja | Block → AAIF/Linux Foundation, "shaped MCP", extensiones MCP nativas |
| 8 | **Aider** | `skool aider` / `aider skool integration` | Bajo-medio (aider mcp = decenas/mes) | ~0 | Transaccional/dev | Muy baja | MCP vía MCPM-Aider / AiderDesk (no nativo puro). Base instalada grande |
| 9 | **CrewAI** | `skool crewai` / `crewai skool tool` | Medio (crewai tools = cientos/mes) | ~0 | Dev/framework | Muy baja | `MCPServerAdapter` + BaseTool. Top framework role-based. Cristian YA lo usa (crews/) |
| 10 | **LangChain** | `skool langchain` (YA EXISTE) | Alto (langchain tool = miles/mes) | ~0 | Dev/framework | Baja | Página viva — revisar/refrescar, no crear |
| 11 | **LlamaIndex** | `skool llamaindex` / `llamaindex skool tool` | Medio (llamaindex tools = cientos/mes) | ~0 | Dev/framework | Muy baja | FunctionTool + LlamaHub. Par natural de LangChain |
| 12 | **AutoGen** | `skool autogen` | Bajo (en maintenance mode → Agent Framework) | ~0 | Dev/framework | Baja | DECLINANDO: Microsoft lo movió a maintenance, empuja "Microsoft Agent Framework". No invertir página dedicada |
| 13 | **OpenClaw** | `skool openclaw` / `openclaw skool` | Bajo-medio (creciendo: 145K stars, OpenAI feb-2026) | ~0 | Dev/nicho-propio | Muy baja | DOBLE rol: framework OSS popular Y stack propio de Cristian (Nyx). Sorprendentemente NO tan nicho |
| 14 | **Hermes** | `skool hermes` | ~0 (nombre ambiguo: Hermes-LLM de NousResearch, Hermes msg queue, etc.) | ~0 | Nicho-propio | Alta (ambigüedad) | NICHO PROPIO. Sin volumen, nombre colisiona con otros productos. Mención, no página |
| 15 | **Continue** | `skool continue` / `continue.dev skool` | Bajo (continue mcp = decenas/mes) | ~0 | Dev | Muy baja | MCP-aware, ya mencionado en skool-mcp. Candidato de segunda ola |
| 16 | **Devin** | `skool devin` | Bajo (Devin es producto cerrado, sin custom-tool abierto típico) | ~0 | — | Alta (cerrado) | NO viable: Devin no expone integración custom-tool al usuario final estándar. Descartar |

### Fuentes de validación
- Claude Code Skills ecosystem ("1,000+ skills", el sistema de extensión que más crece): [code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills), [getbeam.dev guía 2026](https://getbeam.dev/blog/claude-code-skills-ecosystem-guide.html)
- Cursor MCP (`~/.cursor/mcp.json`, plugin/extension API): [cursor.com/docs/mcp](https://cursor.com/docs/mcp)
- Cline (deepest native MCP, marketplace): [cline.bot](https://cline.bot/), [github.com/cline/cline](https://github.com/cline/cline)
- Windsurf (Cascade MCP, plugin store, `~/.codeium/windsurf/mcp_config.json`): [docs.windsurf.com/windsurf/cascade/mcp](https://docs.windsurf.com/windsurf/cascade/mcp)
- OpenCode (#1 HN, 120K stars, 5M devs/mes): [opencode.ai/docs/mcp-servers](https://opencode.ai/docs/mcp-servers/), [github.com/opencode-ai/opencode](https://github.com/opencode-ai/opencode)
- Gemini CLI MCP (settings.json, FastMCP): [geminicli.com/docs/tools/mcp-server](https://geminicli.com/docs/tools/mcp-server/)
- Goose (Block → AAIF/Linux Foundation, shaped MCP): [github.com/block/goose](https://github.com/block/goose), [arcade.dev goose-the-open-source-agent-that-shaped-mcp](https://www.arcade.dev/blog/goose-the-open-source-agent-that-shaped-mcp/)
- Aider MCP (MCPM-Aider, AiderDesk): [github.com/hotovo/aider-desk](https://github.com/hotovo/aider-desk)
- CrewAI (MCPServerAdapter + BaseTool): [docs.crewai.com/en/concepts/tools](https://docs.crewai.com/en/concepts/tools)
- LlamaIndex (FunctionTool, LlamaHub): [developers.llamaindex.ai tools](https://developers.llamaindex.ai/python/framework/module_guides/deploying/agents/tools/)
- AutoGen maintenance mode → Microsoft Agent Framework: [github.com/microsoft/autogen](https://github.com/microsoft/autogen)
- OpenClaw (145K stars, OpenAI adquirió feb-2026): [github.com/abhi1693/openclaw-mission-control](https://github.com/abhi1693/openclaw-mission-control), [zenvanriel.com openclaw guide](https://zenvanriel.com/ai-engineer-blog/openclaw-multi-agent-orchestration-guide/)

---

## 2. Priorización

Criterio de decisión: **(demanda del head term del tool × encaje técnico real con el actor × esfuerzo de mantenimiento)**. Como el long-tail "skool [tool]" es ~0 para todos, lo que diferencia es: (a) cuánta gente usa la herramienta y por tanto puede encontrar la página desde búsquedas adyacentes / vía su propio agente, y (b) si la integración técnica es limpia (MCP nativo = página fácil y honesta) o forzada.

### Tier 1 — Página propia, prioridad alta (crear primero)
Herramientas de IA-coding con MCP/Skills nativo + base de usuarios masiva. Máximo retorno por topical authority y por citación de agentes.

| Ranking | Página | Slug propuesto | Por qué primero |
|---|---|---|---|
| 1 | **Skool + Claude Code** | `integrations/skool-claude-code.md` | Skill YA construido (`skills/claude-code/skool-actor/`). Cero esfuerzo de código nuevo. Ecosistema de skills explotando. Diferenciarla de `skool-claude` (API genérica) — esta es CLI/Skill, drop-in |
| 2 | **Skool + Cursor** | `integrations/skool-cursor.md` | Producto IA-coding más buscado. MCP nativo trivial (`~/.cursor/mcp.json`). Reutiliza el bloque MCP de `skool-mcp` |
| 3 | **Skool + Cline** | `integrations/skool-cline.md` | Deepest native MCP + marketplace activo = audiencia que YA instala MCP servers a diario |
| 4 | **Skool + Windsurf** | `integrations/skool-windsurf.md` | Cascade MCP nativo + plugin store. Config de una línea |
| 5 | **Skool + OpenCode** | `integrations/skool-opencode.md` | 5M devs/mes, crecimiento más rápido. Audiencia OSS que adopta tooling sin fricción |

### Tier 2 — Página propia, prioridad media (segunda ola)
MCP/tool nativo, demanda media, encaje claro. Crear tras validar que Tier 1 indexa y trae sesiones.

| Página | Slug | Nota |
|---|---|---|
| **Skool + Gemini CLI** | `integrations/skool-gemini-cli.md` | MCP nativo + respaldo Google. Buen complemento al `skool-gpt`/`skool-claude` para cubrir "los tres grandes" en CLI |
| **Skool + Goose** | `integrations/skool-goose.md` | MCP nativo, comunidad fiel, "shaped MCP" da buen ángulo de credibilidad |
| **Skool + CrewAI** | `integrations/skool-crewai.md` | `MCPServerAdapter` + BaseTool. Cristian lo usa (`crews/`) → podemos mostrar patrón REAL de producción, fuerte E-E-A-T |
| **Skool + LlamaIndex** | `integrations/skool-llamaindex.md` | Cierra el trío de frameworks junto a LangChain + CrewAI. FunctionTool directo |

### Tier 3 — Página propia, prioridad baja / nicho-propio (cola larga)
Volumen ~0 pero refuerzan topical authority y narrativa de dogfooding. Crear solo cuando Tier 1+2 estén vivos.

| Página | Slug | Nota |
|---|---|---|
| **Skool + OpenClaw** | `integrations/skool-openclaw.md` | Reclasificado de "nicho propio" a **viable**: 145K stars, adquirido por OpenAI. Doble valor: rankea por el head term emergente Y documenta el stack real de Nyx (dogfooding genuino = E-E-A-T máximo). Página corta honesta |
| **Skool + Aider** | `integrations/skool-aider.md` | MCP vía MCPM-Aider/AiderDesk (no nativo puro). Honestidad: la página debe decir que requiere el bridge. Menor prioridad por fricción técnica |
| **Skool + Continue** | `integrations/skool-continue.md` | Solo si sobra capacidad. MCP-aware. Hoy basta con mencionarlo en `skool-mcp` |

### Mención dentro de otra página (NO página propia)
- **Hermes** → mención en `docs/agents.md` o en una sección "other agents" del hub. Nombre ambiguo (colisiona con Hermes-LLM de NousResearch, message brokers, etc.), volumen ~0. Una página propia diluiría autoridad y crearía thin content. Si Cristian quiere documentar su uso interno, va como ejemplo en `docs/agents.md` junto a OpenClaw/Nyx.
- **AutoGen** → mención en hub + nota "en maintenance mode, ver Microsoft Agent Framework". NO página: Microsoft lo está deprecando, sería invertir en una keyword en declive.
- **Devin** → mención mínima o ninguna. Producto cerrado sin custom-tool abierto al usuario final → no hay integración honesta que documentar.
- **Microsoft Agent Framework / Semantic Kernel / OpenAI Agents SDK / Google ADK** → candidatos FUTUROS de tercera ola (los frameworks de los labs están consolidándose). Monitorear volumen; cuando "agent framework + tool" madure, evaluar páginas. Hoy: mención en hub.

### Resumen del ranking final (por orden de creación)
1. Claude Code · 2. Cursor · 3. Cline · 4. Windsurf · 5. OpenCode → **(Tier 1, lote 1)**
6. Gemini CLI · 7. Goose · 8. CrewAI · 9. LlamaIndex → **(Tier 2, lote 2)**
10. OpenClaw · 11. Aider · 12. Continue → **(Tier 3, lote 3, opcional)**
Menciones: Hermes, AutoGen, Devin, Agent Framework, Semantic Kernel.

---

## 3. Estructura óptima de una página "Skool + [agente]"

Doble objetivo: (a) SEO clásico, (b) ser **parseable y citable por un agente IA** que la lee para recomendar el actor. El orden está optimizado para que tanto el crawler como el LLM extraigan la respuesta en los primeros 300 tokens.

### Front matter (consistente con el patrón existente)
```yaml
---
title: "Skool + [Tool] — [verbo de acción] a Skool Community with [Tool] (2026)"
description: "[1 frase: qué habilita] + [path de integración: MCP/Skill/tool] + [keywords: skool, api, automate]." # 150-160 chars
slug: /integrations/skool-[tool]
type: integration
primary_keyword: "skool [tool]"
search_volume_monthly: [estimado real — usar el dato honesto, p.ej. 0 o 10]
funnel: A
playbook: integrations
last_updated: 2026-MM-DD
canonical: https://skool-api.cristiantala.com/integrations/skool-[tool]/
---
```

### Orden de secciones

1. **`> Quick reference (TL;DR for agents)`** *(blockquote, PRIMERO, sin H2)*
   El bloque más importante para la citación por LLM. 3-5 bullets:
   - **What this enables:** [Tool] reads AND writes to Skool (approve members, post, reply, publish courses) como tools nativos.
   - **Integration path:** la vía más limpia para ESTA herramienta (MCP nativo / Skill / tool definition). Una sola, la recomendada.
   - **Setup:** la línea de config exacta (ej. el snippet `mcpServers` con `@apify/actors-mcp-server --actor=cristiantala/skool-all-in-one-api`).
   - **Cost:** Apify pay-per-event (~$0.005–$0.01 por acción).
   - **Latency:** ~2s por call (si aplica).
   Este bloque debe ser **autosuficiente**: un agente que lea solo esto ya puede actuar.

2. **`## Why [Tool] + Skool?`** *(1-2 párrafos, 100-150 palabras)*
   - Una frase de por qué Skool no tiene API oficial → el actor wraps todo el admin surface.
   - Por qué ESTA herramienta encaja (MCP nativo / Skill system / framework de tools). Mencionar el dato de adopción real (ej. "OpenCode crossed 5M monthly devs") para frescura + E-E-A-T.
   - Mención del actor con link UTM-tagged (`utm_campaign=skool-[tool]`).

3. **`## Setup` (path principal, 1 solo camino primario)** *(el bloque de copy-paste)*
   - La config exacta de ESA herramienta (ubicación del archivo, snippet JSON/comando).
   - Pasos numerados: get Apify token → `auth:login` para cookies → pegar config → restart → probar.
   - Para herramientas MCP-nativas: reutilizar el bloque canónico de `skool-mcp.md` (Option A hosted gateway) adaptado al config path de la herramienta.

4. **`## Example session` / `## What you can ask`** *(prueba de que funciona)*
   - Transcript en blockquote `> User:` / `> [Tool]:` mostrando un flujo real (ej. "approve pending members with verified LinkedIn"). Mismo formato que `skool-mcp.md`.
   - Esto ancla la intención y da snippets ricos para featured/PAA.

5. **`## Common patterns`** *(tabla)*
   - Tabla `| Pattern | Implementation |` (igual a `skool-claude.md`): approval queue, daily digest, comment replies, course publishing.
   - Reutilizable casi 1:1 entre páginas — mantener consistencia.

6. **`## [Tool]-specific gotchas`** *(diferenciador anti-thin-content)*
   - 3-5 bullets ÚNICOS de esta herramienta: dónde vive el config, límite de timeout de tool-call, cómo maneja env vars/secrets, naming convention de tools. Esto evita que las páginas sean duplicate content y es lo que un agente cita como "valor real".
   - Siempre incluir el gotcha de cookies (`WAF_EXPIRED` ~3.5 días) + `memberId` vs `id`.

7. **`## Related`** *(internal linking — ver §4)*
   - 4-6 links: el hub, `skool-mcp` (si es MCP-nativa), 1-2 páginas hermanas del mismo tier, `docs/agents.md`, `for/ai-agents.md`, el/los recipe(s) relevante(s).

8. **CTA final** *(idéntico al patrón)*
   - `## Plug Skool into [Tool] today` + link al actor con UTM + ref link de Skool signup.

9. **JSON-LD `TechArticle`** *(al cierre, igual al patrón)*
   - Incluir `headline`, `datePublished`, `author` (Cristian Tala). Considerar agregar `@type: HowTo` con `step` para las páginas de Setup → elegibilidad de rich results "how-to" y mejor parsing por SGE.

### Reglas anti-thin-content (crítico con 12 páginas similares)
- El TL;DR, el Why y los gotchas DEBEN ser únicos por herramienta (≥40% contenido distinto).
- Common patterns + el bloque "qué es el actor" pueden ser compartidos (boilerplate aceptable).
- **NO** publicar dos páginas con setup idéntico cambiando solo el nombre. Si Cursor/Cline/Windsurf comparten exactamente el mismo `mcpServers` snippet, cada una debe diferenciarse por: config path real, gotcha propio, example session distinto, y un párrafo "why this tool" con dato de adopción propio.
- Canonical self-referencing en cada una (ya en el patrón).

---

## 4. Internal linking map

Objetivo: distribuir link equity desde/hacia el hub y crear clusters densos que señalen topical authority. El hub `integrations/index.md` es el **pillar**; cada `skool-[tool]` es **cluster content**.

### 4.1 Hub `integrations/index.md` (cambios)
Agregar una **segunda tabla** debajo de "All integrations", titulada **"By AI agent / coding tool"**, separando claramente:
```
## By AI agent / coding tool
| Tool | Type | Guide |
|---|---|---|
| Claude Code | CLI + Skill | skool-claude-code.md |
| Cursor | IDE (MCP) | skool-cursor.md |
| Cline | VS Code (MCP) | skool-cline.md |
| Windsurf | IDE (MCP) | skool-windsurf.md |
| OpenCode | Terminal (MCP) | skool-opencode.md |
| Gemini CLI | CLI (MCP) | skool-gemini-cli.md |
| Goose | Agent (MCP) | skool-goose.md |
| CrewAI | Framework | skool-crewai.md |
| LlamaIndex | Framework | skool-llamaindex.md |
| OpenClaw | Orchestration | skool-openclaw.md |
```
La tabla existente queda como "automation stacks + LLM modalities". Así Google ve dos clusters temáticos bien definidos bajo un mismo hub.

### 4.2 Reglas de enlace entre páginas nuevas
- **Cada página `skool-[tool]` enlaza HACIA ARRIBA al hub** (`../integrations/index.md` o el slug `/integrations`) — obligatorio, en `## Related`.
- **Cada página MCP-nativa enlaza a `skool-mcp.md`** como "el patrón general MCP" (Cursor, Cline, Windsurf, OpenCode, Gemini CLI, Goose → todas apuntan a `skool-mcp`). `skool-mcp` se vuelve un **mini-hub MCP** y debe enlazar de vuelta a las 6 (linking recíproco = cluster fuerte).
- **Cada página enlaza a `../docs/agents.md`** ("function-calling specs + mistakes to avoid"). `docs/agents.md` ya menciona Cursor/Cline/OpenClaw/Nyx → actualizarlo para enlazar a las páginas dedicadas cuando existan.
- **Cada página enlaza a `../docs/actions.md`** (referencia completa de acciones) — el developer necesita el catálogo de actions; es la página de soporte natural.
- **Cada página enlaza a `../for/ai-agents.md`** (pillar de "Skool for AI agents").
- **Linking lateral por tier/afinidad** (2-3 hermanas, no más, para no diluir):
  - Claude Code → Cursor, Cline, `skool-claude` (la API genérica, para diferenciar)
  - Cursor → Cline, Windsurf, `skool-mcp`
  - Cline → Cursor, Windsurf, `skool-mcp`
  - Windsurf → Cursor, Cline, `skool-mcp`
  - OpenCode → Claude Code, Gemini CLI, `skool-mcp`
  - Gemini CLI → `skool-gpt`, `skool-claude`, OpenCode
  - Goose → `skool-mcp`, OpenCode, `docs/agents.md`
  - CrewAI → `skool-langchain`, LlamaIndex, `docs/agents.md`
  - LlamaIndex → `skool-langchain`, CrewAI, `docs/agents.md`
  - OpenClaw → `docs/agents.md`, CrewAI, `for/ai-agents.md`
- **`skool-claude` (existente) debe actualizarse**: su Path 3 "Claude Code Skill" hoy vive embebido. Cuando exista `skool-claude-code.md`, dejar en `skool-claude` un resumen corto + link "→ Full guide: Skool + Claude Code". Evita canibalización entre `skool-claude` (API/Desktop) y `skool-claude-code` (CLI/Skill). Definir intención clara:
  - `skool-claude` = Anthropic API + Claude Desktop (MCP) → audiencia que construye con la API.
  - `skool-claude-code` = Claude Code CLI + Skill drop-in → audiencia que vive en la terminal.

### 4.3 Enlaces HACIA las nuevas páginas desde contenido existente
- `docs/agents.md` → su tabla "Quick comparison" y la sección MCP ya nombran Cursor/Cline/Claude Code/OpenClaw → convertir esos nombres en links a las páginas dedicadas (refuerza el cluster desde una página de docs con autoridad).
- `for/ai-agents.md` (pillar) → agregar sección "Per-tool guides" enlazando a las Tier 1.
- `learn/skool-api-documentation.md` → si menciona agentes, enlazar al hub de agent integrations.

### Diagrama del cluster
```
                    integrations/index.md  (HUB / pillar)
                   /          |            \
        [automation stacks]   |        [AI agent/tool cluster]  ← tabla nueva
        n8n/make/zapier/...   |          /    |    \    \
                              |   claude-code cursor cline windsurf opencode
                              |          \    |    /    /
                       docs/agents.md ←── skool-mcp.md (mini-hub MCP) ──→ gemini-cli/goose
                              |                                          crewai/llamaindex
                       docs/actions.md  ←─── (todas linkean aquí)         openclaw (tail)
                              |
                       for/ai-agents.md (pillar IA)
```

---

## 5. Relación con recipes

Los `recipes/` son contenido "task-oriented" (cómo lograr X) que complementa las páginas de integración (cómo conectar Y). Hoy existen 9 recipes, incluido `use-skool-api-as-mcp-tool.md` (genérico Claude/Cursor/Cline). La estrategia: **los recipes proveen la prueba de ejecución que las páginas de integración linkean como "ver un caso completo"**.

### 5.1 Recipes existentes a reutilizar (linkear desde las nuevas páginas)
- `use-skool-api-as-mcp-tool.md` → linkear desde TODAS las páginas MCP-nativas (Cursor, Cline, Windsurf, OpenCode, Gemini CLI, Goose) en su `## Related`. Es el recipe paraguas MCP.
- `auto-approve-members-n8n.md`, `reply-unanswered-posts.md`, `publish-course-from-markdown.md` → linkear como "the task an agent runs" en la sección Common patterns de cada página. El developer ve la integración (página) Y la receta concreta (recipe).

### 5.2 Recipes nuevos a crear (refuerzan el cluster de agentes)
Priorizados por cuánto refuerzan las páginas Tier 1 y por ser dogfooding real de Cristian:

| Recipe propuesto | Slug | Refuerza | Por qué |
|---|---|---|---|
| **Run a Skool community manager as a Claude Code Skill** | `recipes/skool-community-manager-claude-code-skill.md` | Claude Code (Tier 1 #1) | Caso E2E REAL: el Skill que Cristian usa en CAR (approve + reply + digest). Dogfooding genuino, screenshots/transcript reales. Máximo E-E-A-T |
| **Connect Skool to Cursor in 2 minutes** | `recipes/skool-cursor-quickstart.md` | Cursor (Tier 1 #2) | Quickstart ultra-corto, intención "skool cursor setup". Linkea a la página de integración para profundidad |
| **Build a Skool tool for your CrewAI crew** | `recipes/skool-tool-for-crewai.md` | CrewAI (Tier 2) | Cristian YA tiene crews (`crews/video-producer`). Mostrar BaseTool real envolviendo el actor. Código de producción |
| **Autonomous Skool moderation with an MCP agent** | `recipes/autonomous-skool-moderation-mcp.md` | Cline/Windsurf/Goose (multi-tool) | Recipe agnóstico de herramienta (cualquier cliente MCP) → linkeable desde 4+ páginas. Cubre el loop "monitor → classify → act → human-approve" del `docs/agents.md` |
| **Dogfooding: how Nyx runs a Skool community with OpenClaw** | `recipes/nyx-openclaw-skool-automation.md` | OpenClaw (Tier 3) | El caso real del stack de Cristian. Honestidad total = autoridad. Cierra el loop "el autor usa lo que documenta" |

### 5.3 Principio de división de contenido (recipe vs integration page)
- **Integration page** = "cómo CONECTAR Skool a [tool]" (setup, config, paths). Estable, cambia poco.
- **Recipe** = "cómo LOGRAR [tarea] con Skool + [tool]" (workflow completo, código de producción). Más narrativo, más E-E-A-T.
- Cada par se enlaza recíprocamente: la página dice "see the full recipe →", el recipe dice "see the integration setup →". Esto duplica las rutas de entrada SEO sin duplicar contenido.

---

## 6. Plan de ejecución sugerido (no ejecutar hasta aprobación)

**Lote 1 (Tier 1, ~5 páginas):** Claude Code → Cursor → Cline → Windsurf → OpenCode.
Crear `skool-claude-code` primero (Skill ya existe, cero código nuevo) + actualizar `skool-claude` para deslindar intención. Crear las 4 MCP-nativas reutilizando el bloque canónico de `skool-mcp` con gotchas/example únicos. Actualizar hub con la tabla nueva. Actualizar `docs/agents.md` para linkear.

**Lote 2 (Tier 2, ~4 páginas):** Gemini CLI → Goose → CrewAI → LlamaIndex.
Crear los 2 recipes de framework (CrewAI, MCP-agnóstico) en paralelo.

**Lote 3 (Tier 3, opcional):** OpenClaw → Aider → Continue.
Crear recipe de dogfooding Nyx/OpenClaw. Menciones de Hermes/AutoGen/Devin en hub + `docs/agents.md`.

**Medición (Funnel A):** trackear por `utm_campaign=skool-[tool]` en Apify analytics qué páginas generan runs reales del actor. La página `skool-claude` ya reporta que claude.ai es el 5º referrer del actor → señal de que el canal funciona. Indexar vía GSC (sitemap del doc-site), monitorear impresiones por keyword "skool [tool]" y, sobre todo, citaciones en respuestas de agentes/SGE (consultas manuales a Perplexity/Claude con web "how to connect skool to cursor").

---

## 7. Notas de E-E-A-T y consistencia
- **Dogfooding como diferenciador:** las páginas más fuertes serán las de herramientas que Cristian REALMENTE usa (Claude Code, CrewAI, OpenClaw/Nyx). Ahí hay experiencia de primera mano genuina → priorizar transcripts/código reales sobre teoría. NO inventar uso de herramientas que no se usan (regla `feedback_no_inventar_contenido`).
- **search_volume_monthly honesto:** poner el dato real (a menudo 0–10). El valor de estas páginas NO es el volumen exacto del long-tail sino topical authority + citación por agentes. Documentarlo así en el front matter es coherente con el patrón existente (`skool claude` = 10, `skool mcp` = 10).
- **Idioma:** el doc-site es EN (audiencia developer global / funnel A). Esta estrategia mantiene EN para las páginas. Prosa de este documento interno en español neutro por convención del repo padre.
- **Consistencia con CLAUDE.md:** OpenClaw aquí se trata como framework OSS público (145K stars) Y como base del stack Nyx de Cristian — ambos roles son ciertos y se refuerzan. Hermes queda como nicho-propio sin página (coherente con el brief original).

---

## 8. Validación con datos reales (DataForSEO) + tesis de monopolio de nicho

Volúmenes reales medidos con DataForSEO (Google Ads, `location_code: 2840` US, 21-may-2026). **Es data US** — Skool es producto US-céntrico, el agregado mundial es mayor (anglosfera + traducciones) pero la priorización no cambia. Para el agregado global exacto, correr más `location_code` (UK 2826, India 2356, CA 2124, AU 2036).

| Keyword | Vol/mes (US) | CPC | Competencia | Lectura |
|---|---:|---:|---|---|
| `skool community` | **6.600** | $0.85 | LOW | head del producto (no es nuestro target directo) |
| `skool api` | **140** | **$10.28** | LOW | **pillar #1** — intención comercial alta, casi sin competencia |
| `skool scraper` | 20 | **$14.74** | LOW | CPC altísimo → intención de compra fuerte |
| `skool zapier` | 20 | — | LOW | |
| `skool n8n / make / mcp / claude / gpt / python / webhook / bot / automation / claude code / scrape skool / scrape skool members` | ~10 c/u | $0 | LOW | cola de cobertura |
| `skool langchain / cursor / cline / opencode / crewai / how to scrape skool / automate skool / skool api alternative / export skool members / unofficial skool api / skool rest api` | <10 (0 reportado) | — | ~0 | long-tail de intención, **competencia cero** |

### Qué confirman los datos

1. **Tesis de monopolio de nicho (principio rector, definido por Cristian 21-may):** *"ser el único que soluciona el problema con un actor de Apify; no necesitamos muchos clientes para que sea rentable."* Los datos lo respaldan: Skool **no tiene API oficial** + competencia LOW/cero en todo el cluster + CPC $10–15 en los términos comerciales. Es un nicho de **alta intención y sin alternativa** → el que llega convierte, y con pay-per-event en Apify bastan **pocos clientes** para ser rentable. El objetivo NO es escala de tráfico, es **capturar el 100% de la demanda de intención de un nicho sin competidores**.

2. **Re-encuadre del objetivo de las páginas por agente** (los datos lo exigen): nadie busca "skool cursor" / "skool cline" / "skool crewai" (vol 0). Por lo tanto esas páginas **no se crean para rankear su propio término** sino para:
   - **(a) Cobertura total del nicho** — cada forma en que un dev podría buscar/preguntar "Skool + [su stack]" tiene una respuesta nuestra.
   - **(b) Citation bait para LLMs** — cuando un dev le pregunta a su propio agente (Claude/Cursor/etc.) "¿cómo conecto Skool?", que la respuesta nos cite por ser **la única fuente**. El "TL;DR for agents" arriba es para esto.
   - **(c) Capturar el long-tail de intención comercial** — `scrape skool members`, `export skool members`, `unofficial skool api`, `skool api alternative` (CPC alto, competencia cero) vía contenido específico + recipes.

3. **Activo #1 = el pillar `skool api`** (140/mes, CPC $10.28, LOW). Es donde está el dinero de búsqueda. Las páginas por agente y los recipes existen para **alimentar topical authority hacia ese pillar**, no para competir por tráfico propio.

### KPIs (coherentes con la tesis)

- **Métrica primaria:** runs del actor en Apify, atribuidos con `utm_campaign=skool-[tool]` por página (ya hay señal: claude.ai es el 5º referrer del actor). NO pageviews.
- **Segunda vía de monetización:** signups a Skool vía el **referral link** (`?ref=114150f098fc40ba9b365fa78be01a63`, 40% recurring forever) — todo CTA "no tienes comunidad Skool todavía" debe llevarlo. Ya es regla en el playbook + template. Un dev que llega a integrar Skool y aún no tiene comunidad = doble monetización (actor + referral).
