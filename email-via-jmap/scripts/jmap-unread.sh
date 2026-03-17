#!/bin/bash
# Check for unread emails
# Usage: jmap-unread.sh [FOLDER] [LIMIT]
# Returns unread message count and previews

set -euo pipefail

JMAP_HOST="${JMAP_HOST:-api.fastmail.com}"
FOLDER="${1:-inbox}"
LIMIT="${2:-10}"

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

# Get mailboxes to find target and get unread count
MAILBOXES=$(curl -sf -X POST "$API_URL" \
    -H "Authorization: Bearer ${JMAP_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail"],
        "methodCalls": [["Mailbox/get", {"accountId": "'"$ACCOUNT_ID"'", "properties": ["id", "name", "role", "unreadEmails"]}, "m"]]
    }')

# Find mailbox by role
MAILBOX_LINE=$(echo "$MAILBOXES" | grep -o '{[^}]*"role":"'"$FOLDER"'"[^}]*}' | head -1)
if [[ -z "$MAILBOX_LINE" ]]; then
    MAILBOX_LINE=$(echo "$MAILBOXES" | grep -oi '{[^}]*"name":"'"$FOLDER"'"[^}]*}' | head -1)
fi

MAILBOX_ID=$(echo "$MAILBOX_LINE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
UNREAD_COUNT=$(echo "$MAILBOX_LINE" | grep -o '"unreadEmails":[0-9]*' | cut -d':' -f2)

if [[ -z "$MAILBOX_ID" ]]; then
    echo "ERROR: Could not find mailbox: $FOLDER" >&2
    exit 1
fi

echo "Unread in $FOLDER: ${UNREAD_COUNT:-0}"

if [[ "${UNREAD_COUNT:-0}" -gt 0 ]]; then
    # Get unread messages
    curl -sf -X POST "$API_URL" \
        -H "Authorization: Bearer ${JMAP_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail"],
            "methodCalls": [
                ["Email/query", {
                    "accountId": "'"$ACCOUNT_ID"'",
                    "filter": {"inMailbox": "'"$MAILBOX_ID"'", "notKeyword": "$seen"},
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
fi
