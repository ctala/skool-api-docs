#!/usr/bin/env bash
# Skool All-in-One API — members:approve helper
# Usage:
#   ./approve.sh <memberId>
#
# Reads SKOOL_COOKIES, SKOOL_GROUP_SLUG, APIFY_TOKEN from .env

set -eo pipefail

ENV_PATH="${SKOOL_ENV_PATH:-./.env}"
[ -f "$ENV_PATH" ] && set -a && . "$ENV_PATH" && set +a

: "${APIFY_TOKEN:?APIFY_TOKEN is required}"
: "${SKOOL_COOKIES:?SKOOL_COOKIES is required}"
: "${SKOOL_GROUP_SLUG:?SKOOL_GROUP_SLUG is required}"

MEMBER_ID="$1"
[ -z "$MEMBER_ID" ] && { echo "Usage: approve.sh <memberId>"; exit 1; }

PAYLOAD=$(python3 -c "
import json, os
print(json.dumps({
  'action': 'members:approve',
  'cookies': os.environ['SKOOL_COOKIES'],
  'groupSlug': os.environ['SKOOL_GROUP_SLUG'],
  'params': { 'memberId': os.environ['M'] },
}))
" M="$MEMBER_ID")

curl -fsS -X POST "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=${APIFY_TOKEN}&build=latest&timeout=60" \
  -H 'Content-Type: application/json' \
  -d "$PAYLOAD" | python3 -c "
import json, sys
d = json.load(sys.stdin)[0]
if d.get('success') is False:
    if 'cannot update to same role' in d.get('error', ''):
        print(f'⚠️  member already approved (no-op)')
        sys.exit(0)
    print(f'❌ {d.get(\"errorCode\")}: {d.get(\"error\")}', file=sys.stderr)
    print(f'   hint: {d.get(\"hint\")}', file=sys.stderr)
    sys.exit(1)
print(f'✓ member approved')"
