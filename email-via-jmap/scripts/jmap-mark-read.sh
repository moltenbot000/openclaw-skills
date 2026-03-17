#!/bin/bash
# Mark email(s) as read
# Usage: jmap-mark-read.sh <EMAIL_ID> [EMAIL_ID...]
#
# Examples:
#   jmap-mark-read.sh Stqal4BuPYVZ
#   jmap-mark-read.sh Stqal4BuPYVZ Stqal5SAHfg3

set -euo pipefail

JMAP_HOST="${JMAP_HOST:-api.fastmail.com}"

if [[ $# -lt 1 ]]; then
    echo "Usage: jmap-mark-read.sh <EMAIL_ID> [EMAIL_ID...]" >&2
    exit 1
fi

if [[ -z "${JMAP_TOKEN:-}" ]]; then
    echo "ERROR: JMAP_TOKEN environment variable not set" >&2
    exit 1
fi

# Get session info
SESSION=$(curl -sf -H "Authorization: Bearer ${JMAP_TOKEN}" "https://${JMAP_HOST}/jmap/session")
API_URL=$(echo "$SESSION" | grep -o '"apiUrl":"[^"]*"' | cut -d'"' -f4)
ACCOUNT_ID=$(echo "$SESSION" | grep -o '"urn:ietf:params:jmap:mail":"[^"]*"' | head -1 | cut -d'"' -f4)

if [[ -z "$API_URL" || -z "$ACCOUNT_ID" ]]; then
    echo "ERROR: Could not parse JMAP session" >&2
    exit 1
fi

# Build update object for all email IDs
UPDATE_OBJ="{"
FIRST=true
for EMAIL_ID in "$@"; do
    if [[ "$FIRST" == "true" ]]; then
        FIRST=false
    else
        UPDATE_OBJ+=","
    fi
    UPDATE_OBJ+="\"${EMAIL_ID}\": {\"keywords/\$seen\": true}"
done
UPDATE_OBJ+="}"

# Mark as read by setting $seen keyword
RESULT=$(curl -sf -X POST "$API_URL" \
    -H "Authorization: Bearer ${JMAP_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
        \"using\": [\"urn:ietf:params:jmap:core\", \"urn:ietf:params:jmap:mail\"],
        \"methodCalls\": [[\"Email/set\", {
            \"accountId\": \"${ACCOUNT_ID}\",
            \"update\": ${UPDATE_OBJ}
        }, \"m\"]]
    }")

# Check for errors
if echo "$RESULT" | grep -q '"updated"'; then
    UPDATED_COUNT=$(echo "$RESULT" | grep -o '"updated":{[^}]*}' | grep -o '"[^"]*":' | wc -l)
    echo "✅ Marked ${UPDATED_COUNT} email(s) as read"
else
    echo "❌ Failed to mark as read"
    echo "$RESULT"
    exit 1
fi
