# n8n Templates — submission queue for n8n.io

Official n8n templates derived from our recipes, to publish on [n8n.io/workflows](https://n8n.io/workflows) (n8n.io is already a referrer to the actor). Each template = a high-DA page linking back to the docs + actor.

**Hard rules for published templates:**
- **Everything in English** — node names, sticky notes, code comments, AND all placeholders (global dev audience). No `TU_`, no brand names like `Nyx`/`CAR`. Use `YOUR_…` / `__REPLACE_WITH_…__`.
- **No secrets / no branding** — placeholders only, generic copy.
- **Document to #13868 standard** — ship the template already documented like n8n's auto-doc workflow produces: (a) a **group sticky note wrapping each node group** (placed first in the JSON `nodes` array so it renders *behind* the nodes), (b) **node-level `notes`** (`notes` + `notesInFlow: true`) on every functional node, (c) an **Overview** sticky, and (d) a **Setup/configuration** sticky with step-by-step config (credentials + every Config field + where to get each value). The Setup sticky is mandatory. Running #13868 (step 4 below) then mainly renames nodes — our content is already there.

**How to submit each one** (manual, from the n8n.io creator account — same as the existing [Auto-approve template #14392](https://n8n.io/workflows/14392-auto-approve-skool-community-members-with-gpt-4o-ai-screening/)):
1. Import the `.json` into your n8n instance.
2. Configure credentials (Apify, WhatsApp/Telegram, LLM) — the JSON ships with placeholders only.
3. Test it runs end-to-end against a real community.
4. n8n.io → **Submit a workflow** with the title/description/categories below. Their **AI review** reads your workflow — because we pre-document it (group stickies + node notes + Setup), the AI cleanly extracts Title + overview + how-it-works + setup — and **auto-generates an improved JSON** with refined sticky notes (shown as *"copy the updated JSON here"*). This is n8n's own #13868 auto-annotation run for you — **no need to run #13868 yourself**.
5. **Copy that improved JSON** → re-upload in *"Upload updated workflow JSON"* → **Submit for human review**.
6. After publish, add the n8n.io URL to the matching recipe page (like the auto-approve recipe links its template), and save the final published JSON back here as canonical.

UTM on the actor links inside the sticky notes: `utm_campaign=n8n-skool-{slug}`.

---

## 1. ✅ READY — Send weekly Skool events to WhatsApp

**File:** `skool-events-to-whatsapp.json` (generalized from a production workflow — validated, runs live).

- **Title:** Send weekly Skool community events to WhatsApp (Evolution API)
- **Description:** Every Monday, fetch your Skool community's upcoming events via the [Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?fpr=cristian) and post a formatted summary to a WhatsApp group via Evolution API. Fresh login each run (no cookie management), silent skip when there are no events. Swap the final node for Telegram/Slack/email if you don't use Evolution.
- **Categories:** Marketing, Communication
- **Nodes:** Schedule Trigger · Apify (auth:login, events:list) · Code (filter + format) · IF · HTTP Request (Evolution sendText)
- **Recipe:** [Automate Skool events](../recipes/automate-skool-events.md)
- **Status:** ready to import + submit. Already production-validated, so low risk.

---

## 2. ✅ READY — Reply to unanswered Skool posts

**File:** `reply-unanswered-skool-posts.json` (generic build, import-validated in n8n DEV).

- **Title:** Reply to unanswered Skool posts with an LLM (human-approved)
- **Description:** Find Skool community posts with 0 comments, draft an on-brand reply with an LLM (OpenRouter — swap for any LLM), and send it to Telegram for human review. Keeps engagement up without manual monitoring. Extend with `posts:createComment` to auto-publish after approval.
- **Categories:** AI, Marketing, Communication
- **Nodes:** Schedule · Apify (auth:login, posts:filter) · Code (filter candidates) · HTTP Request (LLM draft) · Code (format) · Telegram
- **Recipe:** [Reply to unanswered posts](../recipes/reply-unanswered-posts.md)
- **Status:** ready. Built generic (no NocoDB/KB coupling, LLM via HTTP so no fragile langchain deps, **no affiliate link**) and validated by a clean import to n8n DEV. Configure credentials + Config, test, then submit.
