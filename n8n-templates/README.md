# n8n Templates — submission queue for n8n.io

Official n8n templates derived from our recipes, to publish on [n8n.io/workflows](https://n8n.io/workflows) (n8n.io is already a referrer to the actor). Each template = a high-DA page linking back to the docs + actor.

**Hard rules for published templates:**
- **Everything in English** — node names, sticky notes, code comments, AND all placeholders (global dev audience). No `TU_`, no brand names like `Nyx`/`CAR`. Use `YOUR_…` / `__REPLACE_WITH_…__`.
- **No secrets / no branding** — placeholders only, generic copy.

**How to submit each one** (manual, from the n8n.io creator account — same as the existing [Auto-approve template #14392](https://n8n.io/workflows/14392-auto-approve-skool-community-members-with-gpt-4o-ai-screening/)):
1. Import the `.json` into your n8n instance.
2. Configure credentials (Apify, WhatsApp/Telegram, LLM) — the JSON ships with placeholders only.
3. Test it runs end-to-end against a real community.
4. **Pass it through n8n's official [Auto-generate sticky notes & rename nodes template (#13868)](https://n8n.io/workflows/13868-auto-generate-sticky-notes-and-rename-nodes/)** — n8n.io expects submitted workflows to follow this standard (clean descriptive node names + explanatory sticky notes). Run it on the workflow before submitting.
5. n8n.io → **Submit a workflow** (or in-app Share → publish to template library): paste the exported workflow, title, description, categories below.
6. After publish, add the n8n.io URL to the matching recipe page (like the auto-approve recipe links its template).

UTM on the actor links inside the sticky notes: `utm_campaign=n8n-skool-{slug}`.

---

## 1. ✅ READY — Send weekly Skool events to WhatsApp

**File:** `skool-events-to-whatsapp.json` (generalized from a production workflow — validated, runs live).

- **Title:** Send weekly Skool community events to WhatsApp (Evolution API)
- **Description:** Every Monday, fetch your Skool community's upcoming events via the [Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api) and post a formatted summary to a WhatsApp group via Evolution API. Fresh login each run (no cookie management), silent skip when there are no events. Swap the final node for Telegram/Slack/email if you don't use Evolution.
- **Categories:** Marketing, Communication
- **Nodes:** Schedule Trigger · Apify (auth:login, events:list) · Code (filter + format) · IF · HTTP Request (Evolution sendText)
- **Recipe:** [Automate Skool events](../recipes/automate-skool-events.md)
- **Status:** ready to import + submit. Already production-validated, so low risk.

---

## 2. ⏳ NEEDS BUILD + DEV VALIDATION — Reply to unanswered Skool posts

**Why not shipped yet:** the production version (`workflows/community/nyx-comments-copilot.json`) is **tightly coupled** to our infra — NocoDB dedup table, Cofre/Cursos knowledge bases, OpenRouter creds. A public template must be **generic and import-clean**. Building the generic version (Cron → `posts:filter` unanswered → relevance filter → LLM draft → Telegram approval → `posts:createComment`) requires correct n8n typeVersions + a clean import test — improvising the JSON risks a broken template, which would hurt the "GO TO" reputation (a broken official template is worse than none).

- **Title:** Reply to unanswered Skool posts with an LLM (human-approved)
- **Description:** Find Skool community posts with 0 comments, draft an on-brand reply with an LLM (Claude/GPT), send to Telegram for one-tap approval, then publish via the Skool All-in-One API actor. Keeps engagement up without manual monitoring.
- **Categories:** AI, Marketing, Communication
- **Recipe:** [Reply to unanswered posts](../recipes/reply-unanswered-posts.md) (already documents the generic flow)
- **Plan:** build the generic workflow in the `workflows/` submodule with the n8n pipeline (flow-architect → json-specialist → qa-tester) + validate with the n8n MCP, OR adapt `nyx-comments-copilot` (strip NocoDB/KB nodes, generalize the posts fetch to an Apify node) and **test-import in n8n DEV before submitting**. Do NOT publish unvalidated.
