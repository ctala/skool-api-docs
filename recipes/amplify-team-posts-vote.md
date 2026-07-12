---
title: "Auto-amplify Skool posts from team accounts (likes / unlikes via API)"
description: "Use posts:vote to systematically like or unlike posts from team accounts. Honest framing on when this is legitimate validation vs when it becomes fake engagement."
slug: /recipes/amplify-team-posts-vote
type: recipe
funnel: A
section: Recipes
last_updated: 2026-05-28
render_with_liquid: false
---

# Auto-amplify team posts (likes via API)

`posts:vote` toggles the like state on a Skool post. The action exists for legitimate cases: a team account validating a community post by another member, a moderator boosting a high-quality contribution to the top of the feed, or syncing your own multi-account workflows.

**This recipe also exists to draw the ethical line clearly.** The same action used wrong becomes fake engagement — a pattern that erodes community trust, violates Skool's spirit, and (more pragmatically) gets flagged by Skool's anti-abuse heuristics. Read the "when not to use this" section before automating anything.

## Quick reference (TL;DR for agents)

| | |
|---|---|
| **Goal** | Programmatically like / unlike posts from a team account |
| **Stack** | Any HTTP client + the Apify-hosted actor |
| **Actions used** | [`posts:list`](../docs/posts.md#postslist) / [`posts:filter`](../docs/posts.md#postsfilter) → [`posts:vote`](../docs/posts.md#postsvote) |
| **Setup time** | ~5 min |
| **Ongoing cost** | `$0.01` per vote toggle |
| **Key constraint** | One vote per account per post — you can't pad a like count from one account |
| **Mandatory read** | "When NOT to use this" section below |

## When this is legitimate

- **Team account validation.** Your founder account + your VA account + your designer account each genuinely read a member's post and find it useful — likes from those accounts are honest signal, the same way they'd be in any channel.
- **Cross-account workflow sync.** You run a Skool community AND a moderator account; both your own. You like your own community announcements from the moderator account to make sure they surface in the "Recent activity" feed for members who follow your moderator profile.
- **Catching up after travel.** You were offline a week. You bulk-like the posts your team would have liked in real time, to retroactively signal "the founder saw this."

## When NOT to use this — this matters

- **Fake engagement from burner accounts.** Creating sock-puppet accounts to like your own posts is dishonest. Skool members notice when likes don't translate to comments or attendance. Trust erodes faster from inflated metrics than from low metrics honestly reported.
- **Manipulating the algorithm to push promo posts.** Even if technically your team accounts, batch-liking promo content to game Skool's feed ranking is the same pattern Twitter / LinkedIn engagement pods do. Members can smell it.
- **Liking competitor posts in your own community to feign neutrality.** Don't.

If you're not sure whether your use case is honest, ask: *"Would I be comfortable explaining this to a member who asked?"* If no, don't automate it.

## Prerequisites

- Apify token ([sign up free](https://console.apify.com/sign-up?fpr=cristian))
- Skool cookies for each team account that will vote (one cookie per account — `posts:vote` votes from the authenticated account)
- A clear policy on which posts get liked from team accounts (don't decide post-by-post)

## Step 1 — Find posts to like

By recency:

```json
{
  "action": "posts:list",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "limit": 20 }
}
```

By keyword (e.g. all posts in a category your team validates):

```json
{
  "action": "posts:filter",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": { "labelId": "anuncios_label_id", "since": "2026-05-28T00:00:00Z" }
}
```

## Step 2 — Vote (like or unlike)

```json
{
  "action": "posts:vote",
  "cookies": "...",
  "groupSlug": "your-community",
  "params": {
    "postId": "abc123...32hex",
    "vote": "like"
  }
}
```

| `vote` value | Effect |
|---|---|
| `"like"` | Add a like from the authenticated account (idempotent — re-like is no-op) |
| `"unlike"` | Remove the like from the authenticated account |

Response:

```json
{
  "success": true,
  "postId": "abc123...",
  "currentVoteCount": 12,
  "currentUserVoted": true
}
```

`currentVoteCount` is the total likes after your action. `currentUserVoted` confirms your account's state — useful when scripting toggles.

## Step 3 — Multi-account workflows

If you're syncing likes across multiple team accounts (founder + VA + designer), loop per account by switching the cookie:

```python
ACCOUNTS = [
    {"name": "founder", "cookies": FOUNDER_COOKIES},
    {"name": "va", "cookies": VA_COOKIES},
    {"name": "designer", "cookies": DESIGNER_COOKIES},
]

for post in valuable_posts:
    for account in ACCOUNTS:
        run_action("posts:vote", {
            "cookies": account["cookies"],
            "postId": post["id"],
            "vote": "like"
        })
```

Each account contributes its honest signal. **No more than 3-4 team accounts** in this pattern — beyond that you're padding numbers, not validating.

## Production gotchas

- **One vote per account per post.** Re-calling `posts:vote` with `like` from the same account is a no-op (Skool just returns the current state). You can't stack likes from one account.
- **Skool tracks like-to-comment ratios in its anti-abuse heuristics.** A community with 500 likes and 5 comments looks suspicious to Skool — both internally and to potential members browsing your community profile. Likes should track engagement, not exceed it.
- **`posts:vote` doesn't notify the author.** Likes are silent in Skool — there's no notification fired. So you can't use this to "ping" members, only to influence sort order.
- **Skool feed sort is recency-weighted, not like-weighted.** Heavy liking won't move an old post to the top — it'll just make recent posts look more validated. Don't expect viral-style algorithmic boost.
- **Cookie scope.** Each team account has its own cookies that expire ~3.5 days. Multi-account workflows mean refreshing N cookie sets — automate the auth loop or this becomes the bottleneck.

## See also

- [Posts API reference](../docs/posts.md) — `posts:vote` + related actions
- [Recipe: Keyword monitoring auto-replies](keyword-monitoring-replies.md) — the *reply* path for adding value to posts (honestly stronger signal than likes)
- [Skool community guidelines](https://www.skool.com/help) — what Skool considers acceptable team coordination vs. abuse

---

## Use this in production — no setup

The hardest part of building Skool automation isn't the API logic — it's the auth (cookies expire every ~3.5 days, WAF token rotation, weekly Skool buildId changes). The **[Skool All-in-One API actor on Apify](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=amplify-team-posts-vote&fpr=cristian)** handles all of that.

- Pay-per-event pricing (~$1.50/mo for typical communities)
- `posts:vote` + `posts:list` / `posts:filter` wrapped behind one JSON-over-HTTP surface
- Built by a solo community admin — the team-account use case here is the founder + virtual assistant setup, not engagement pods

[**→ Open the actor on Apify**](https://apify.com/cristiantala/skool-all-in-one-api?utm_source=skool-api-docs&utm_medium=recipe&utm_campaign=amplify-team-posts-vote&fpr=cristian)

*New to Skool? [Launch your community here](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial.*

<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "HowTo",
  "name": "Auto-amplify Skool team posts (likes via API)",
  "description": "Use posts:vote to like or unlike posts from team accounts, with honest framing on when it is legitimate validation versus fake engagement.",
  "totalTime": "PT5M",
  "tool": [
    {"@type": "HowToTool", "name": "Apify"},
    {"@type": "HowToTool", "name": "Skool admin cookies"}
  ],
  "step": [
    {"@type": "HowToStep", "name": "Find posts to like", "text": "Call posts:list by recency or posts:filter by labelId to surface the posts your team account will validate."},
    {"@type": "HowToStep", "name": "Vote like or unlike", "text": "Call posts:vote with the postId and vote set to like or unlike. One vote per account per post, and re-liking is a no-op."},
    {"@type": "HowToStep", "name": "Loop across team accounts", "text": "Switch the cookie per team account (founder, VA, designer) to contribute each account's honest signal. Keep it to 3-4 accounts."}
  ]
}
</script>
