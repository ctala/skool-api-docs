# Getting Started

Get from "I have a Skool community" to "I'm automating it" in 10 minutes.

## Prerequisites

- An [Apify account](https://apify.com?fpr=cristian) (free tier is enough to test). Grab your API token from [account → integrations](https://console.apify.com/account/integrations?fpr=cristian).
- A Skool account that has admin (or at least relevant role) on the community you want to automate. *(Don't have a Skool community yet? [Launch one here](https://www.skool.com/signup?ref=114150f098fc40ba9b365fa78be01a63) — 14-day free trial, no credit card.)*

## Two auth modes

The actor supports two authentication strategies. Pick one:

### Mode A — Email + Password (every call)

Pass `email` and `password` in every action. The actor logs in via headless Playwright (~10 seconds) on every run. Simpler, slower, more expensive.

### Mode B — Cookies (recommended)

Run `auth:login` once, save the returned cookies, and pass `cookies` in every subsequent action (~2 seconds per run). Cookies last ~3.5 days before the AWS WAF token rotates and you need to login again.

This guide uses **Mode B**.

## 1. Login once and save cookies

Replace `YOUR_TOKEN`, `your-email@example.com`, `your-password`, and `your-community-slug` with your values.

```bash
curl -X POST "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=YOUR_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "action": "auth:login",
    "email": "your-email@example.com",
    "password": "your-password",
    "groupSlug": "your-community-slug"
  }'
```

The community slug is the part of the URL after `skool.com/`. For example, in `https://www.skool.com/cagala-aprende-repite`, the slug is `cagala-aprende-repite`.

A successful response looks like:

```json
[{
  "success": true,
  "cookies": "auth_token=eyJ...; client_id=abc...; aws-waf-token=xyz...",
  "expiresAt": "2026-05-09T18:00:00.000Z",
  "expiresInDays": 3.5,
  "note": "Pass this cookies string in subsequent calls to skip Playwright login."
}]
```

Save the `cookies` value somewhere your other workflows can read — environment variable, n8n credential, secret store, whatever fits your stack.

## 2. List posts (read example)

```bash
curl -X POST "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=YOUR_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "action": "posts:list",
    "cookies": "auth_token=...; client_id=...; aws-waf-token=...",
    "groupSlug": "your-community-slug",
    "params": { "page": 1 }
  }'
```

Response shape:

```json
[{
  "success": true,
  "posts": [
    {
      "id": "32-char-hex",
      "title": "Post Title",
      "content": "Plain text content",
      "author": { "id": "...", "firstName": "John", "lastName": "Smith", "slug": "john-smith" },
      "createdAt": "2026-05-06T18:00:00Z",
      "likes": 5,
      "commentCount": 12,
      "isPinned": false,
      "url": "https://www.skool.com/your-community/post-slug"
    }
  ],
  "page": 1,
  "total": 86,
  "hasMore": true
}]
```

## 3. Create a post (write example)

```bash
curl -X POST "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=YOUR_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "action": "posts:create",
    "cookies": "auth_token=...; client_id=...; aws-waf-token=...",
    "groupSlug": "your-community-slug",
    "params": {
      "title": "Hello from Apify",
      "content": "This was created via the API. Plain text only — no HTML."
    }
  }'
```

> **Important:** `content` is **plain text**. Skool does NOT render HTML, markdown, or rich formatting in posts/comments. Tags like `<p>` will appear literally. The only resource that uses rich formatting is **course pages** (TipTap JSON, see [classroom docs](classroom.md)).

If your community **requires categories**, the call will fail with `MISSING_CATEGORY` and a `hint` telling you to pass `params.labelId`. Get available `labelId`s with `groups:get`.

## 4. Replying to a post (creating a comment)

In Skool, **posts and comments are the same object**. A comment is a post with `rootId` and `parentId` set:

```bash
curl -X POST "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=YOUR_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "action": "posts:createComment",
    "cookies": "...",
    "groupSlug": "your-community-slug",
    "params": {
      "rootId": "POST_ID",
      "parentId": "POST_ID",
      "content": "Welcome! Glad you joined."
    }
  }'
```

For **top-level comments**, `rootId == parentId == postId`.
For **nested replies** to another comment, `rootId == postId` (always the original post) but `parentId == commentId`.

## 5. Handling failures

The actor never throws. Every failure ships as a structured `{success:false, errorCode, hint, retryable}` payload:

```json
[{
  "success": false,
  "action": "posts:createComment",
  "error": "post not found: 3bc910b1",
  "errorCode": "NOT_FOUND",
  "errorCategory": "not_found",
  "statusCode": 404,
  "retryable": false,
  "hint": "Verify the ID provided in params. If it was valid before, the resource may have been deleted."
}]
```

Always check `dataset[0].success` before treating the response as a result. If `success === false`, log `errorCode` + `hint` for diagnosis. See [Error handling](error-handling.md) for the full catalog.

## What's next

- [Authentication deep dive](authentication.md) — how cookies, WAF, and buildId rotation actually work
- [Posts & comments full reference](posts.md) — all read/write operations, mentions, pagination
- [Classroom](classroom.md) — build entire courses programmatically
- [Recipes](../README.md#recipes) — copy-paste integrations for n8n, Make.com, custom code
