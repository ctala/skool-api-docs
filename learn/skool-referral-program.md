---
title: "Skool Referral Program — How the 40% Commission Works (2026)"
description: "Skool's referral program: 40% recurring forever, Stripe payouts, monthly. Mechanics, eligibility, payout schedule, integration with course affiliate options."
slug: /learn/skool-referral-program
type: glossary
primary_keyword: "skool referral program"
search_volume_monthly: 20
funnel: B
playbook: glossary
last_updated: 2026-05-19
canonical: https://skool-api.cristiantala.com/learn/skool-referral-program/
---


> **TL;DR.** Skool's referral program pays **40% recurring forever** to anyone who refers a new Skool community owner. Built into the platform. Stripe payouts. No tiers, no caps. This is the same as the "affiliate program" — Skool uses both terms interchangeably. For the marketing-focused breakdown see [skool affiliate program](skool-affiliate-program.md). This page covers the mechanics.

## What the referral program actually is

Every Skool customer (anyone paying $99/mo) has a unique referral URL of the form:

```
https://www.skool.com/signup?ref=<your_unique_id>
```

When someone signs up via that URL and stays on Skool (their trial converts to paid), Skool pays you **40% of every $99/mo they pay**, every month, indefinitely.

Example: you refer 10 people who each stay on Skool. They each pay Skool $99/mo. Skool pays you $39.60/mo × 10 = $396/mo. Forever, as long as they remain customers.

## Payout mechanics

- **Frequency:** monthly (calendar month-end)
- **Minimum threshold:** $50 — held until you cross it, then paid
- **Method:** Stripe Connect (you set up payouts in your Skool affiliate dashboard)
- **Tax docs:** Skool issues a 1099 (US) or equivalent foreign reporting where applicable
- **Currency:** USD (Skool's billing currency)

## Tracking and attribution

When someone clicks your ref link:

1. Skool drops a tracking cookie
2. If they sign up within the cookie window (typically 30-60 days), the signup is attributed to you
3. Their account is permanently tagged as "referred by [your_id]"
4. Commissions flow as long as that account stays active

Edge cases:

- **Click ref link A, then ref link B, then sign up** — last-click wins (B gets attribution)
- **Click ref link, don't sign up, return 90 days later and sign up** — beyond cookie window, no attribution
- **Sign up directly without ref link, then a friend gives you a ref link** — too late, no attribution
- **Reactivate canceled account** — attribution restores if the original ref still applies; no attribution if signed up directly the second time

## Eligibility

Anyone with a paid Skool community (their own $99/mo subscription) can use the referral program. New customers in trial don't have the affiliate dashboard yet — it unlocks once the first $99 payment processes.

**Disqualified:**

- Self-referrals (using your own link to sign up another account)
- Same-household / same IP / same credit card referrals
- Bot-generated signups
- Anyone who's been banned from Skool for terms violations

Detection is automated. Don't try to game it.

## Course-level affiliate eligibility

Inside your community, you can sell individual courses (one-time payment, not subscription). For each course, you can toggle `is_afl_comp_eligible`:

- **`true`** (default) — your community members can earn referral commission when they refer someone who buys this course
- **`false`** — no commission paid for referrals to this course (you keep 100%)

Use case for `false`: high-margin VIP workshops where you don't want to share commission with members who refer the workshop.

This is a course-level setting, separate from the platform-level Skool referral program (which is always 40% / forever on the $99/mo platform fee).

## Reporting in the affiliate dashboard

Once active, your dashboard shows:

- **Signups attributed** — total ever
- **Active referred users** — currently paying Skool
- **Earned this month** — accruing toward payout
- **Lifetime earnings** — total ever
- **Pending payout** — held until threshold crossed
- **Stripe Connect status** — whether your payout setup is complete

The dashboard does not show your individual referrals' email addresses (privacy). You can see the count and aggregate metrics only.

## Integration with content marketing

Your ref link is just a URL. You can:

- Drop it in blog posts (`Sign up at [Skool](https://www.skool.com/signup?ref=...)`)
- Link from YouTube descriptions
- Mention in podcasts (use a memorable short alias via your own URL shortener)
- Embed in email newsletters (with proper disclosure)
- Include in social bio (Twitter, LinkedIn, Instagram)
- Reference in this exact docs site you're reading

Most successful Skool affiliates I've talked to drive volume from one of: (a) a YouTube channel with founder/business content + recommend-your-stack videos, (b) a podcast where they interview Skool community owners, (c) a newsletter where they recommend tools weekly.

## Common questions

### Is the 40% forever guaranteed in writing?

It's Skool's published commission structure, and they pay it consistently. Skool reserves the right to change the program (any platform does), but historically the 40%/forever has been stable since launch.

### Can I run paid ads (Google, Facebook) with my ref link?

Skool's terms don't explicitly forbid it, but most platforms require approval before running paid campaigns directly to a referral link. Check with their support if you plan a paid budget. Organic content is unambiguously OK.

### Can I write a review and use my ref link?

Yes. Standard affiliate marketing. Disclose ("This is an affiliate link" or "I earn a commission" or similar) where required by your jurisdiction.

### What if Skool cuts the commission rate in the future?

Existing referrals are typically grandfathered at the original rate. New signups under your link after a rate change would use the new rate. This is standard SaaS affiliate program behavior. Always read the current terms in your dashboard.

### How long does it take to make meaningful money?

Depends entirely on your audience. Founders / creators with 10K+ followers in the right niche can hit $1K-$5K/month in 3-6 months. From cold start with no audience, plan a 12-24 month ramp.

## Related

- [Skool affiliate program (marketing-focused view)](skool-affiliate-program.md)
- [Skool pricing](../guide/skool-pricing.md)
- [Skool community platform](skool-community-platform.md)
- [Is Skool legit?](../guide/is-skool-legit.md)

---

## Get your referral link — start your own Skool

[**→ Create your Skool community**](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial. After your first $99 payment, the affiliate dashboard unlocks and your ref link is active.

*Building solo and want to automate? [Use this Apify actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=glossary&utm_campaign=skool-referral-program&fpr=cristian) — no code required, ~$1.50/mo.*

<script type="application/ld+json">
{"@context":"https://schema.org","@type":"Article","headline":"Skool Referral Program","datePublished":"2026-05-19","author":{"@type":"Person","name":"Cristian Tala"}}
</script>
