#!/usr/bin/env bash
# Skool All-in-One API — members:batchApprove helper
# Approve N pending applicants in one actor run (per-item results, $0.01 × N).
#
# Usage:
#   ./batch-approve.sh <memberId1> <memberId2> ...      # ids as args
#   ./batch-approve.sh < ids.txt                        # one memberId per line on stdin
#   members:pending | jq -r '.[].memberId' | ./batch-approve.sh
#
# ⚠️  Pass memberId (NOT the `id` field) from members:pending. The `id` is the
#     request id and gives a silent 404 on role updates.
#
# Reads SKOOL_COOKIES, SKOOL_GROUP_SLUG, APIFY_TOKEN from .env

set -eo pipefail

ENV_PATH="${SKOOL_ENV_PATH:-./.env}"
[ -f "$ENV_PATH" ] && set -a && . "$ENV_PATH" && set +a

: "${APIFY_TOKEN:?APIFY_TOKEN is required}"
: "${SKOOL_COOKIES:?SKOOL_COOKIES is required}"
: "${SKOOL_GROUP_SLUG:?SKOOL_GROUP_SLUG is required}"

# Collect memberIds from args, or from stdin if none given
if [ "$#" -gt 0 ]; then
  IDS=("$@")
else
  IDS=()
  while IFS= read -r line; do
    line="$(echo "$line" | tr -d '[:space:]')"
    [ -n "$line" ] && IDS+=("$line")
  done
fi

[ "${#IDS[@]}" -eq 0 ] && { echo "Usage: batch-approve.sh <memberId> [memberId...]   (or pipe ids on stdin)"; exit 1; }

echo "Approving ${#IDS[@]} member(s) via members:batchApprove..."

PAYLOAD=$(IDS_JSON="$(printf '%s\n' "${IDS[@]}")" python3 -c "
import json, os
ids = [x for x in os.environ['IDS_JSON'].split('\n') if x]
print(json.dumps({
  'action': 'members:batchApprove',
  'cookies': os.environ['SKOOL_COOKIES'],
  'groupSlug': os.environ['SKOOL_GROUP_SLUG'],
  'params': { 'memberIds': ids },
}))
")

curl -fsS -X POST "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=${APIFY_TOKEN}&build=latest&timeout=120" \
  -H 'Content-Type: application/json' \
  -d "$PAYLOAD" | python3 -c "
import json, sys
rows = json.load(sys.stdin)
# batchApprove returns a per-item array; a top-level failure returns a single object
if isinstance(rows, dict) or (rows and isinstance(rows[0], dict) and 'success' in rows[0] and 'memberId' not in rows[0]):
    d = rows if isinstance(rows, dict) else rows[0]
    print(f'❌ {d.get(\"errorCode\")}: {d.get(\"error\")}', file=sys.stderr)
    print(f'   hint: {d.get(\"hint\")}', file=sys.stderr)
    sys.exit(1)
ok = sum(1 for r in rows if r.get('success'))
for r in rows:
    mark = '✓' if r.get('success') else '❌'
    extra = '' if r.get('success') else f\"  ({r.get('error','')})\"
    print(f'  {mark} {r.get(\"memberId\")}{extra}')
print(f'\\nApproved {ok}/{len(rows)}.')
sys.exit(0 if ok == len(rows) else 1)
"
