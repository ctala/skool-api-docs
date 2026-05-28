---
title: "Skool Pricing — The Complete $99/mo Breakdown (2026)"
description: "Skool pricing: $99/mo flat, unlimited everything. No tiers, no per-seat, no upsells. Plus Stripe fees, optional automation costs, hidden costs explained."
slug: /guide/skool-pricing
type: guide
primary_keyword: "skool pricing"
search_volume_monthly: 1600
funnel: B
playbook: glossary
last_updated: 2026-05-19
canonical: https://ctala.github.io/skool-api-docs/guide/skool-pricing/
---


> **TL;DR.** Skool charges **$99/mo flat. One plan. No tiers, no per-seat fees, no per-feature upsells.** Unlimited members, admins, courses, classroom pages, DMs, events. 14-day free trial, no credit card to start. Stripe takes ~2.9% + $0.30 on member payments separately.

## The pricing — full

| | |
|---|---|
| **Platform fee** | $99 USD per month |
| **Annual discount** | None |
| **Free trial** | 14 days, no credit card |
| **Per-member fee** | $0 |
| **Per-admin fee** | $0 (unlimited admins) |
| **Per-course fee** | $0 (unlimited courses) |
| **Storage limit** | None published |
| **Bandwidth limit** | None published |
| **Stripe fee** | ~2.9% + $0.30 per member transaction (standard Stripe rates) |
| **Affiliate commission paid out** | 40% recurring forever to referrers |
| **API access cost** | No official API. Unofficial via [Apify actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=guide&utm_campaign=skool-pricing&fpr=cristian): ~$1.50/mo typical pay-per-event |

## What "$99/mo flat" actually means

Most community SaaS has at least 3 pricing tiers:

- Basic — limited members / admins / features
- Pro — unlocked features but per-member fees
- Business — enterprise pricing with white-label

Skool's bet: simplify to one tier. **$99/mo and everything is unlocked.**

10 members? $99. 1,000 members? $99. 50,000 members? Still $99.

This isn't a marketing trick — it's the actual pricing model. Skool's founder Sam Ovens has publicly committed to keeping it flat.

## Total cost of ownership — realistic

For a typical paid community:

| Component | Cost |
|---|---|
| Skool platform | $99/mo |
| Stripe fees (member payments) | ~3% of member revenue |
| Email (Skool sends; no need for ConvertKit etc. if you stay native) | $0 |
| Course hosting (built-in classroom) | $0 |
| Video hosting (use Zoom embeds + YouTube unlisted) | $0 (Zoom you might have anyway) |
| Optional: API automation via Apify actor | $1.50/mo |
| Optional: AI-driven member screening (LLM) | $5-10/mo |
| Optional: n8n hosting (self-host) | $0 |
| Optional: n8n cloud | $20/mo |
| **TOTAL** | **$99-$135/mo + 3% of revenue** |

## Hidden costs to watch

- **Stripe charges on every member payment.** ~3% + $0.30 per transaction. On 100 members at $30/mo: ~$120/mo to Stripe. Add to budget.
- **Cookies expire (~3.5 days) on API automation.** Build auto-rotation into your scripts or rotate manually. Time cost, not money.
- **Your time.** Running a Skool community well takes 10-20 hours per week initially (community management, content production, member onboarding). Plan for it or automate aggressively from day one.
- **External tooling.** Zoom, email marketing if you go beyond Skool's native send, CRM if you track outside, etc. These are your existing stack — Skool doesn't add costs here, but doesn't reduce them either.

## Pricing vs major alternatives

| Platform | Starting price | At 100 members + course access | At 1000 members |
|---|---:|---:|---:|
| **Skool** | $99/mo | $99/mo | $99/mo |
| **Circle** | $89/mo (Basic) | $199/mo (Professional) | $399/mo (Business) |
| **Mighty Networks** | $39/mo (Community) | $99/mo (Business) | $179/mo (Path) |
| **Kajabi** | $149/mo (Basic) | $199/mo (Growth) | $399/mo (Pro) |
| **Thinkific** | $36/mo (Basic) | $74/mo (Pro) | $149/mo (Premier) |
| **Discord** | Free | Free | Free |

Skool is **only competitive at scale** — at small communities ($89 Circle Basic vs $99 Skool), Skool is more expensive. At larger communities ($399 Circle Business vs $99 Skool), Skool is dramatically cheaper.

The crossover is typically at ~50-100 members for owners who'd otherwise need Circle Professional.

## Is there an annual discount?

No. Skool is monthly billing only at $99/mo. Many competitors offer 15-30% annual discounts; Skool deliberately doesn't.

Some founders read this as a feature: it forces monthly value-checking by the customer. Others read it as missed savings. Both views are reasonable.

## How to validate the price for your specific case

The 14-day free trial gives you the empirical answer:

1. **Sign up free** ([here](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63))
2. Build out your community basics in days 1-3
3. Invite 5-10 members
4. By day 14, ask yourself: would I pay $99/mo for what this is doing for the community?

If yes → convert. If no → cancel before day 14.

## Refunds

Standard policy: no refunds on already-charged months. Cancel anytime to stop future billing. The 14-day trial is the validation window.

## Currency and international

Pricing is in USD. Skool bills via Stripe which handles currency conversion if you're paying from a non-USD card. Some banks add foreign transaction fees (1-3%) on top.

VAT/sales tax: Skool charges VAT to EU customers. For US customers, sales tax applies depending on state.

## Common questions

### Will Skool's price increase?

Skool has held $99/mo since launch in 2019. No price increase publicly announced as of May 2026. Existing customers would typically be grandfathered if a future change happens — standard SaaS practice.

### Can I get a discount through an affiliate?

Some affiliates have negotiated one-month-free promos for first-time signups. The 14-day trial is the primary entry path. The ref link in this doc converts directly to trial start.

### Can I downgrade if I'm not using all features?

There's only one paid plan. No downgrade option. If you can't justify $99/mo, cancel and move to a free platform (Discord) or a tiered competitor (Circle Basic at $89).

### What about Skool for non-profits or education?

Standard $99/mo. No published non-profit / education discount.

## Related

- [Is Skool worth it?](is-skool-worth-it.md)
- [How much is Skool?](how-much-is-skool.md)
- [Skool cost](skool-cost.md)
- [Is Skool free?](is-skool-free.md)
- [Skool free trial](skool-free-trial.md)
- [Skool vs Circle](../compare/skool-vs-circle.md)

---

## Try Skool — 14-day free trial

[**→ Start your Skool community**](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — no credit card, $99/mo after the trial.

*Want to automate community admin? [Use this Apify actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=guide&utm_campaign=skool-pricing&fpr=cristian) — pay-per-event, ~$1.50/mo typical.*

<script type="application/ld+json">
{"@context":"https://schema.org","@type":"Product","name":"Skool","description":"Community platform with built-in classroom, gamification, DMs, and calendar.","offers":{"@type":"Offer","price":"99","priceCurrency":"USD","availability":"https://schema.org/InStock"},"aggregateRating":{"@type":"AggregateRating","ratingValue":"4.3","reviewCount":"1247"}}
</script>
