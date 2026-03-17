#!/bin/bash
# Read a specific email by ID
# Usage: jmap-read.sh <EMAIL_ID>

set -euo pipefail

JMAP_HOST="${JMAP_HOST:-api.fastmail.com}"

if [[ -z "${1:-}" ]]; then
    echo "Usage: jmap-read.sh <EMAIL_ID>" >&2
    exit 1
fi

EMAIL_ID="$1"

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

# Fetch full email
curl -sf -X POST "$API_URL" \
    -H "Authorization: Bearer ${JMAP_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail"],
        "methodCalls": [
            ["Email/get", {
                "accountId": "'"$ACCOUNT_ID"'",
                "ids": ["'"$EMAIL_ID"'"],
                "properties": ["id", "subject", "from", "to", "cc", "bcc", "replyTo", "receivedAt", "sentAt", "textBody", "htmlBody", "bodyValues", "attachments"],
                "fetchAllBodyValues": true
            }, "g"]
        ]
    }'
