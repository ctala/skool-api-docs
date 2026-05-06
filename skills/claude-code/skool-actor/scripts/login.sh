#!/usr/bin/env bash
# Skool All-in-One API — auth:login helper
# Reads credentials from .env in current dir or the dir specified by SKOOL_ENV_PATH.
# Outputs the cookies string (and exit code 0) on success; non-zero on failure.

set -eo pipefail

ENV_PATH="${SKOOL_ENV_PATH:-./.env}"
[ -f "$ENV_PATH" ] && set -a && . "$ENV_PATH" && set +a

: "${APIFY_TOKEN:?APIFY_TOKEN is required (set in .env)}"
: "${SKOOL_EMAIL:?SKOOL_EMAIL is required}"
: "${SKOOL_PASSWORD:?SKOOL_PASSWORD is required}"
: "${SKOOL_GROUP_SLUG:?SKOOL_GROUP_SLUG is required}"

curl -fsS -X POST "https://api.apify.com/v2/acts/cristiantala~skool-all-in-one-api/run-sync-get-dataset-items?token=${APIFY_TOKEN}&build=latest&timeout=120" \
  -H 'Content-Type: application/json' \
  -d "$(cat <<EOF
{
  "action": "auth:login",
  "email": "${SKOOL_EMAIL}",
  "password": "${SKOOL_PASSWORD}",
  "groupSlug": "${SKOOL_GROUP_SLUG}"
}
EOF
)" | python3 -c "
import json, sys
d = json.load(sys.stdin)
if not d or d[0].get('success') is False:
    print(f'❌ login failed: {d[0] if d else \"empty response\"}', file=sys.stderr)
    sys.exit(1)
print(d[0]['cookies'])
"
