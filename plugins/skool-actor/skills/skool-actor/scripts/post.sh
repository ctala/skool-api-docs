#!/usr/bin/env bash
# Skool All-in-One API — posts:create helper
# Usage:
#   ./post.sh "Title" "Plain text content" [labelId]
#
# Reads cookies + groupSlug + APIFY_TOKEN from .env

set -eo pipefail

ENV_PATH="${SKOOL_ENV_PATH:-./.env}"
[ -f "$ENV_PATH" ] && set -a && . "$ENV_PATH" && set +a

: "${APIFY_TOKEN:?APIFY_TOKEN is required}"
: "${SKOOL_COOKIES:?SKOOL_COOKIES is required (run login.sh first)}"
: "${SKOOL_GROUP_SLUG:?SKOOL_GROUP_SLUG is required}"

TITLE="$1"
CONTENT="$2"
LABEL_ID="${3:-}"

[ -z "$TITLE" ] && { echo "Usage: post.sh <title> <content> [labelId]"; exit 1; }
[ -z "$CONTENT" ] && { echo "Usage: post.sh <title> <content> [labelId]"; exit 1; }

if [ ${#TITLE} -gt 50 ]; then
  echo "❌ Title is ${#TITLE} chars, max is 50 (Skool limit)" >&2
  exit 1
fi

PAYLOAD=$(python3 -c "
import json, os
params = { 'title': os.environ['T'], 'content': os.environ['C'] }
if os.environ.get('L'): params['labelId'] = os.environ['L']
print(json.dumps({
  'action': 'posts:create',
  'cookies': os.environ['SKOOL_COOKIES'],
  'groupSlug': os.environ['SKOOL_GROUP_SLUG'],
  'params': params,
}))
" T="$TITLE" C="$CONTENT" L="$LABEL_ID")

curl -fsS -X POST "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=${APIFY_TOKEN}&build=latest&timeout=60" \
  -H 'Content-Type: application/json' \
  -d "$PAYLOAD" | python3 -c "
import json, sys
d = json.load(sys.stdin)[0]
if d.get('success') is False:
    print(f'❌ {d.get(\"errorCode\")}: {d.get(\"error\")}', file=sys.stderr)
    print(f'   hint: {d.get(\"hint\")}', file=sys.stderr)
    sys.exit(1)
post = d.get('post', d)
print(f'✓ post created: {post.get(\"url\", post.get(\"id\"))}')"
