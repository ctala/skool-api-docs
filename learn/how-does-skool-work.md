---
title: "How Does Skool Work? Complete Beginner's Guide (2026)"
description: "How does Skool work? Skool combines a community feed, courses (classroom), gamification, and live events in one platform for $99/mo flat. Full explanation."
slug: /learn/how-does-skool-work
type: glossary
primary_keyword: "how does skool work"
search_volume_monthly: 480
funnel: B
playbook: glossary
last_updated: 2026-05-19
canonical: https://ctala.github.io/skool-api-docs/learn/how-does-skool-work/
---


> **TL;DR.** [Skool](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) is a community + courses platform. You pay $99/mo flat (after 14-day trial). You get one **community** with a feed, a **classroom** for courses, **gamification** (levels + points unlock content), **DMs**, a **calendar** for events. You charge your members whatever you want — Skool's cut is the flat $99/mo from you, not a percentage.

## The four pillars of every Skool community

### 1. The community feed

Reddit-meets-Facebook. Members post questions, wins, polls, resources. Other members comment, upvote (likes). Posts can be categorized by label ("Wins", "Help", "Resources"). Pinned posts at the top. Mobile and desktop, same experience.

This is the **main thing** members see when they open Skool. Engagement here is the leading indicator for retention.

### 2. The classroom

Courses you publish for your members. Each course is a tree of folders and pages. Each page can have rich content (text, video embed, attachments, code blocks). Courses can be free for everyone, or gated by member tier, or unlocked by gamification level.

The classroom UI is simple — no LMS-style assignments or quizzes. If you need that level of structure, Skool isn't the right tool (consider Kajabi or Thinkific). For most knowledge-product communities, simple is exactly right.

### 3. Gamification (levels + points)

This is the underrated Skool feature. Every member starts at Level 1. They earn points by:

- Publishing a post: +1
- Posting a comment: +1
- Receiving a like on their content: +1
- Daily login: +1

Levels go 1 → 9. Each level unlocks something:

- Level 2 might unlock your "Foundations" course
- Level 5 might unlock a private channel
- Level 9 might unlock a 1-on-1 with you

A public **leaderboard** shows the top contributors. This single mechanism drives most of Skool's engagement compounding — members come back to climb levels, post more, get more points.

### 4. DMs + Calendar + Auto DM

- **DMs** — native private messages between members. You can also DM the whole community (max length applies).
- **Calendar** — schedule events with Zoom/Google Meet links. Members RSVP. Embedded live video player when Zoom is running.
- **Auto DM** — the message new members get the moment they join. Up to 300 characters. Tokens `#NAME#` and `#GROUPNAME#` for personalization. This is your single highest-leverage touchpoint with new members.

## How money flows

```
[Your members] ─pay you─→ [You] ─pay $99/mo─→ [Skool]
                            │
                            ├── (Stripe takes ~2.9% + $0.30 per payment)
                            │
                            └── Optional: 40% recurring affiliate commission
                                to whoever referred you to Skool, forever
```

You set the price your members pay. Skool only charges you the flat $99/mo. There's no per-member fee, no per-course fee, no transaction percentage to Skool.

If you got into Skool through someone's affiliate link (like [this one](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63)), 40% of your $99/mo goes to that referrer for as long as you're a Skool customer. This is the highest commission in community-platform SaaS — it's how Skool grew without VC marketing.

## Member tiers (paid vs free)

You decide who pays you what. Common setups:

- **All free** — everyone joins free, you make money via courses sold inside Skool
- **Single paid tier** — $X/mo or $X/year, gets you the community + classroom
- **Hybrid (most common)** — free tier with limited classroom access, paid tier unlocks everything
- **Multiple paid tiers** — bronze/silver/gold style with progressively more content unlocked

You configure these in your community settings. Members upgrade in-platform via Stripe.

## What you can't do natively (and how to work around)

| Limitation | Workaround |
|---|---|
| No native API | [Apify-hosted Skool API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=glossary&utm_campaign=how-does-skool-work) |
| No native webhooks | [Polling proxy pattern](../integrations/skool-webhook.md) |
| No custom domain | Wait or migrate to Circle ($89-$399/mo) for that feature |
| No white-label | Same — migrate to Circle Business plan |
| No course assignments | Kajabi or Thinkific if you need structured course progression |
| Limited theme customization | Logo + cover image only |
| No multi-language | UI is English only |

For most community founders, none of these are dealbreakers. For some specific use cases (enterprise customer communities, multi-region), they matter.

## What a typical Skool day looks like

For the community owner:

- **9am** — check overnight applications, approve or reject (or have it automated, see [auto-approve](../recipes/auto-approve-members-n8n.md))
- **9:30am** — post a "morning thread" (or have it scheduled automatically)
- **10am-12pm** — respond to threads, encourage members posting
- **3pm** — check engagement metrics, see who's stuck (low activity), DM them
- **5pm** — schedule any live events on the calendar

For an active member:

- Open Skool, check feed for new posts in their interest categories
- Comment on 2-3 posts, post 1 question or update
- Complete one classroom lesson
- Watch their level/point progress
- DM a member they want to connect with

That's it. No "platform" complexity, no integration headaches. The whole experience is the four pillars described above.

## How to get started

1. **Sign up for the 14-day free trial** — no credit card needed. [Start here](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63).
2. **Set your community name + cover image** — 5 minutes
3. **Write your first welcome post** — pin it, this is what new members see first
4. **Set your Auto DM** — the message they get on join (max 300 chars; make it specific)
5. **Add your first course** — even a 3-page MVP. The classroom feels real once it has content.
6. **Invite 5 people** — friends, customers, anyone. The feed feels alive at 5 active members.

Most owners hit 20-50 members in the first month if they have an existing audience (email list, social following). If you're starting from zero, plan a 3-6 month ramp.

## Pricing reality check

- **You:** $99/mo to Skool. Flat. Forever. No upsells.
- **Stripe:** ~2.9% + $0.30 on every member payment you process
- **Optional automations:** $0-50/mo depending on what you build (see [Skool automation](../automation/skool-automation.md))

A community with 50 paid members at $30/mo each generates $1,500/mo. Your costs: $99 (Skool) + ~$45 (Stripe) + ~$30 (optional automations) = ~$175/mo. Net: $1,325/mo (~88% margin).

This is why Skool is the dominant "first paid community" platform in 2026 — the unit economics are obvious and predictable.

## Related

- [Is Skool legit?](../guide/is-skool-legit.md)
- [Skool pricing — full breakdown](../guide/skool-pricing.md)
- [Skool vs Circle](../compare/skool-vs-circle.md)
- [Skool vs Mighty Networks](../compare/skool-vs-mighty-networks.md)
- [Skool features](skool-features.md)

---

## Ready to launch your Skool community?

[**→ Create your Skool community**](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial, setup in under 10 minutes.

*Plan to automate from day one? [Use this Apify actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=glossary&utm_campaign=how-does-skool-work) — auto-approve members, schedule posts, ~$1.50/mo.*

<script type="application/ld+json">
{"@context":"https://schema.org","@type":"DefinedTerm","name":"How Skool works","description":"Skool is a community + courses platform combining feed, classroom, gamification, DMs, and calendar for a flat $99/mo. Members pay you whatever you charge — Skool only takes the flat fee from you.","inDefinedTermSet":"https://github.com/ctala/skool-api-docs"}
</script>
