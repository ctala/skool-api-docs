---
title: "Skool Features — Complete List of What Skool Includes (2026)"
description: "Skool features: community feed, classroom, gamification, DMs, calendar, Auto DM, courses, leaderboard, mobile apps. Everything included in the $99/mo plan."
slug: /learn/skool-features
type: glossary
primary_keyword: "skool features"
search_volume_monthly: 110
funnel: B
playbook: glossary
last_updated: 2026-05-19
canonical: https://skool-api.cristiantala.com/learn/skool-features/
---


> **TL;DR.** [Skool](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63)'s $99/mo flat plan includes: community feed, classroom (unlimited courses), gamification (levels + points), DMs, calendar, Auto DM, mobile apps (iOS+Android), Stripe payments, basic analytics, and 40% affiliate program. No upsells, no add-ons.

## Core features

### Community feed
- Reddit-style feed with posts and comments
- Post categories (labels) — you define them
- Pinned posts
- Likes (upvotes), no downvotes
- Plain text + image + video embed in posts
- Nested comment threads (2 levels deep visually)
- Mobile + desktop, same experience

### Classroom
- Unlimited courses
- Each course = tree of folders and pages
- Each page = rich content (text, video embed, attachments, code blocks)
- Drip schedule per page
- Gated by member tier OR by gamification level
- Markdown → TipTap auto-conversion (via [API](../integrations/skool-python.md))

### Gamification
- Levels 1-9 per member
- Points from: posts (+1), comments (+1), likes received (+1), daily login (+1)
- Level unlocks: courses, channels, custom content
- Public leaderboard
- This is the **engagement compounding** mechanism

### DMs
- Private 1:1 between any 2 members
- Group DMs
- Read receipts, typing indicators
- Mobile push notifications

### Calendar
- Schedule events with Zoom / Google Meet / Whereby links
- RSVP from members
- Embedded live video player when Zoom is running
- iCal sync (read-only)

### Auto DM
- Single message every new member gets on join
- ≤300 characters
- Tokens: `#NAME#`, `#GROUPNAME#` for personalization
- Editable anytime in settings

### Member roles
- Owner, Admin, Moderator, Member
- Owner = you (one per community)
- Admins can do everything except billing
- Moderators can hide posts, ban members
- Members vary by tier

### Payment processing
- Native Stripe integration
- Members pay you via Stripe Checkout in-app
- Skool takes $0 of member payments (only the $99/mo from you)
- Recurring subscriptions + one-time payments supported
- Course upsells inside the classroom

### Mobile apps
- iOS (App Store)
- Android (Google Play)
- Native push notifications
- Same features as web

### Affiliate program
- 40% recurring forever for every member you refer to start their own Skool community
- Paid via Stripe Connect
- Tracked automatically with your referral link

### Basic analytics
- Member count + growth chart
- Engagement (posts, comments per day)
- Top contributors
- Course completion rates per course

## What's NOT in Skool

- ❌ Custom domain (`yoursite.com`) — Skool only
- ❌ White-label (remove "Powered by Skool")
- ❌ Custom theme / CSS
- ❌ Custom integrations native (no official API)
- ❌ Email marketing (sends inside Skool only)
- ❌ Course assignments / structured progression
- ❌ Live streaming native (use Zoom embed)
- ❌ Custom landing pages
- ❌ Multi-language UI
- ❌ Advanced analytics (use Apify actor to export data, analyze externally)

The **no API** gap is filled by the [unofficial Apify-hosted Skool All-in-One API actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=glossary&utm_campaign=skool-features&fpr=cristian) — pay-per-event ~$1.50/mo.

## Feature comparison vs Circle / Mighty Networks

See [Skool vs Circle](../compare/skool-vs-circle.md) and [Skool vs Mighty Networks](../compare/skool-vs-mighty-networks.md) for side-by-side.

## Related

- [How does Skool work?](how-does-skool-work.md)
- [Skool pricing](../guide/skool-pricing.md)
- [Skool gamification deep dive](skool-classroom.md)
- [Is Skool worth it?](../guide/is-skool-worth-it.md)

---

## Try Skool — 14-day free trial

[**→ Create your Skool community**](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — no credit card, see every feature in action.

*Plan to automate? [Use this Apify actor](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=glossary&utm_campaign=skool-features&fpr=cristian) — ~$1.50/mo for typical use.*

<script type="application/ld+json">
{"@context":"https://schema.org","@type":"Product","name":"Skool","description":"Community + courses platform with feed, classroom, gamification, DMs, calendar, Auto DM, mobile apps. Flat $99/mo.","offers":{"@type":"Offer","price":"99","priceCurrency":"USD"}}
</script>
