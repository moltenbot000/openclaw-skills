#!/bin/bash
# List emails in a mailbox
# Usage: jmap-list.sh [FOLDER] [LIMIT]
# FOLDER defaults to "inbox" (by role). Can also be a mailbox ID.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JMAP_HOST="${JMAP_HOST:-api.fastmail.com}"
FOLDER="${1:-inbox}"
LIMIT="${2:-20}"

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

# Get mailboxes to find the target folder
MAILBOXES=$(curl -sf -X POST "$API_URL" \
    -H "Authorization: Bearer ${JMAP_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail"],
        "methodCalls": [["Mailbox/get", {"accountId": "'"$ACCOUNT_ID"'"}, "m"]]
    }')

# Find mailbox ID (by role like "inbox" or by direct ID)
MAILBOX_ID=$(echo "$MAILBOXES" | grep -o '"id":"[^"]*","name":"[^"]*","role":"'"$FOLDER"'"' | head -1 | cut -d'"' -f4)
if [[ -z "$MAILBOX_ID" ]]; then
    # Try matching by name (case-insensitive via grep)
    MAILBOX_ID=$(echo "$MAILBOXES" | grep -oi '"id":"[^"]*","name":"'"$FOLDER"'"' | head -1 | cut -d'"' -f4)
fi
if [[ -z "$MAILBOX_ID" ]]; then
    # Assume it's a direct mailbox ID
    MAILBOX_ID="$FOLDER"
fi

# Query emails
curl -sf -X POST "$API_URL" \
    -H "Authorization: Bearer ${JMAP_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail"],
        "methodCalls": [
            ["Email/query", {
                "accountId": "'"$ACCOUNT_ID"'",
                "filter": {"inMailbox": "'"$MAILBOX_ID"'"},
                "sort": [{"property": "receivedAt", "isAscending": false}],
                "limit": '"$LIMIT"'
            }, "q"],
            ["Email/get", {
                "accountId": "'"$ACCOUNT_ID"'",
                "#ids": {"resultOf": "q", "name": "Email/query", "path": "/ids"},
                "properties": ["id", "subject", "from", "receivedAt", "preview"]
            }, "g"]
        ]
    }'
