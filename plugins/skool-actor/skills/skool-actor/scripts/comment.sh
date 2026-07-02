#!/usr/bin/env bash
# Skool All-in-One API — posts:createComment helper
# Usage:
#   ./comment.sh <postId> "Comment text"           # top-level comment
#   ./comment.sh <postId> "Reply text" <commentId> # nested reply
#
# Reads SKOOL_COOKIES, SKOOL_GROUP_SLUG, APIFY_TOKEN from .env

set -eo pipefail

ENV_PATH="${SKOOL_ENV_PATH:-./.env}"
[ -f "$ENV_PATH" ] && set -a && . "$ENV_PATH" && set +a

: "${APIFY_TOKEN:?APIFY_TOKEN is required}"
: "${SKOOL_COOKIES:?SKOOL_COOKIES is required}"
: "${SKOOL_GROUP_SLUG:?SKOOL_GROUP_SLUG is required}"

POST_ID="$1"
CONTENT="$2"
PARENT_COMMENT_ID="$3"

[ -z "$POST_ID" ] && { echo "Usage: comment.sh <postId> <content> [parentCommentId]"; exit 1; }
[ -z "$CONTENT" ] && { echo "Usage: comment.sh <postId> <content> [parentCommentId]"; exit 1; }

# For top-level comments: rootId == parentId == postId
# For nested replies:    rootId == postId, parentId == commentId
PARENT_ID="${PARENT_COMMENT_ID:-$POST_ID}"

PAYLOAD=$(python3 -c "
import json, os
print(json.dumps({
  'action': 'posts:createComment',
  'cookies': os.environ['SKOOL_COOKIES'],
  'groupSlug': os.environ['SKOOL_GROUP_SLUG'],
  'params': {
    'rootId': os.environ['POST_ID'],
    'parentId': os.environ['PARENT_ID'],
    'content': os.environ['C'],
  },
}))
" POST_ID="$POST_ID" PARENT_ID="$PARENT_ID" C="$CONTENT")

curl -fsS -X POST "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=${APIFY_TOKEN}&build=latest&timeout=60" \
  -H 'Content-Type: application/json' \
  -d "$PAYLOAD" | python3 -c "
import json, sys
d = json.load(sys.stdin)[0]
if d.get('success') is False:
    print(f'❌ {d.get(\"errorCode\")}: {d.get(\"error\")}', file=sys.stderr)
    print(f'   hint: {d.get(\"hint\")}', file=sys.stderr)
    sys.exit(1)
print(f'✓ comment created: {d.get(\"id\", d)}')"
