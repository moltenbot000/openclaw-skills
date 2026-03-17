#!/bin/bash
# Send an email via JMAP (v2 - actually sends, doesn't leave in drafts)
# Usage: jmap-send.sh <TO> <SUBJECT> <BODY>
#        jmap-send.sh <TO> <SUBJECT> --file <PATH>
#
# TO can be comma-separated for multiple recipients
# Set JMAP_CC for CC recipients (comma-separated)
# Set JMAP_FROM_NAME to override sender display name

set -euo pipefail

JMAP_HOST="${JMAP_HOST:-api.fastmail.com}"

if [[ $# -lt 3 ]]; then
    echo "Usage: jmap-send.sh <TO> <SUBJECT> <BODY>" >&2
    echo "       jmap-send.sh <TO> <SUBJECT> --file <PATH>" >&2
    echo "" >&2
    echo "TO can be comma-separated: \"alice@example.com,bob@example.com\"" >&2
    echo "Set JMAP_CC for CC recipients" >&2
    exit 1
fi

TO_RAW="$1"
SUBJECT="$2"
shift 2

if [[ -z "${JMAP_TOKEN:-}" ]]; then
    echo "ERROR: JMAP_TOKEN environment variable not set" >&2
    exit 1
fi

# Handle body: either direct text or --file
if [[ "${1:-}" == "--file" ]]; then
    if [[ -z "${2:-}" || ! -f "${2:-}" ]]; then
        echo "ERROR: --file requires a valid path" >&2
        exit 1
    fi
    BODY=$(cat "$2")
else
    BODY="$*"
fi

# Escape JSON special characters in body
BODY_ESCAPED=$(printf '%s' "$BODY" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')

# Get session info
SESSION=$(curl -sf -H "Authorization: Bearer ${JMAP_TOKEN}" "https://${JMAP_HOST}/jmap/session")
API_URL=$(echo "$SESSION" | grep -o '"apiUrl":"[^"]*"' | cut -d'"' -f4)
ACCOUNT_ID=$(echo "$SESSION" | grep -o '"urn:ietf:params:jmap:mail":"[^"]*"' | head -1 | cut -d'"' -f4)

if [[ -z "$API_URL" || -z "$ACCOUNT_ID" ]]; then
    echo "ERROR: Could not parse JMAP session" >&2
    exit 1
fi

# Get mailboxes (need Drafts and Sent folders)
MAILBOXES=$(curl -sf -X POST "$API_URL" \
    -H "Authorization: Bearer ${JMAP_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail"],
        "methodCalls": [["Mailbox/get", {"accountId": "'"$ACCOUNT_ID"'", "properties": ["id", "role"]}, "m"]]
    }')

# Parse mailbox IDs - handle both orderings of id/role
DRAFTS_ID=$(echo "$MAILBOXES" | grep -oE '"(id|role)":"[^"]*"[^}]+"(id|role)":"[^"]*"' | grep 'drafts' | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | head -1)
SENT_ID=$(echo "$MAILBOXES" | grep -oE '"(id|role)":"[^"]*"[^}]+"(id|role)":"[^"]*"' | grep '"sent"' | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | head -1)

if [[ -z "$DRAFTS_ID" ]]; then
    # Fallback: try simpler pattern
    DRAFTS_ID=$(echo "$MAILBOXES" | grep -o '"role":"drafts"' -B1 | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | head -1)
fi
if [[ -z "$SENT_ID" ]]; then
    SENT_ID=$(echo "$MAILBOXES" | grep -o '"role":"sent"' -B1 | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | head -1)
fi

if [[ -z "$DRAFTS_ID" || -z "$SENT_ID" ]]; then
    echo "ERROR: Could not find Drafts or Sent mailbox" >&2
    echo "DEBUG: DRAFTS_ID=$DRAFTS_ID SENT_ID=$SENT_ID" >&2
    exit 1
fi

# Get identity (for sending)
IDENTITIES=$(curl -sf -X POST "$API_URL" \
    -H "Authorization: Bearer ${JMAP_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:submission"],
        "methodCalls": [["Identity/get", {"accountId": "'"$ACCOUNT_ID"'"}, "i"]]
    }')

IDENTITY_ID=$(echo "$IDENTITIES" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
FROM_EMAIL=$(echo "$IDENTITIES" | grep -o '"email":"[^"]*"' | head -1 | cut -d'"' -f4)
FROM_NAME="${JMAP_FROM_NAME:-$(echo "$IDENTITIES" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)}"

if [[ -z "$IDENTITY_ID" || -z "$FROM_EMAIL" ]]; then
    echo "ERROR: Could not find sending identity" >&2
    exit 1
fi

# Build recipient arrays for Email/set (with names)
build_recipients() {
    local raw="$1"
    local result=""
    IFS=',' read -ra ADDRS <<< "$raw"
    for addr in "${ADDRS[@]}"; do
        addr=$(echo "$addr" | xargs) # trim whitespace
        if [[ -n "$addr" ]]; then
            [[ -n "$result" ]] && result+=","
            result+="{\"email\":\"$addr\"}"
        fi
    done
    echo "[$result]"
}

# Build rcptTo array for envelope (just emails)
build_rcpt_to() {
    local raw="$1"
    local result=""
    IFS=',' read -ra ADDRS <<< "$raw"
    for addr in "${ADDRS[@]}"; do
        addr=$(echo "$addr" | xargs)
        if [[ -n "$addr" ]]; then
            [[ -n "$result" ]] && result+=","
            result+="{\"email\":\"$addr\"}"
        fi
    done
    echo "[$result]"
}

TO_JSON=$(build_recipients "$TO_RAW")
CC_JSON="[]"
RCPT_TO=$(build_rcpt_to "$TO_RAW")

if [[ -n "${JMAP_CC:-}" ]]; then
    CC_JSON=$(build_recipients "$JMAP_CC")
    # Add CC recipients to envelope rcptTo
    CC_RCPT=$(build_rcpt_to "$JMAP_CC")
    # Merge arrays (remove brackets, combine, re-add brackets)
    RCPT_TO="[${RCPT_TO:1:-1},${CC_RCPT:1:-1}]"
fi

# Send email with envelope and onSuccessUpdateEmail to move from drafts to sent
RESPONSE=$(curl -sf -X POST "$API_URL" \
    -H "Authorization: Bearer ${JMAP_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
        "using": [
            "urn:ietf:params:jmap:core",
            "urn:ietf:params:jmap:mail",
            "urn:ietf:params:jmap:submission"
        ],
        "methodCalls": [
            ["Email/set", {
                "accountId": "'"$ACCOUNT_ID"'",
                "create": {
                    "draft1": {
                        "mailboxIds": {"'"$DRAFTS_ID"'": true},
                        "from": [{"email": "'"$FROM_EMAIL"'", "name": "'"$FROM_NAME"'"}],
                        "to": '"$TO_JSON"',
                        "cc": '"$CC_JSON"',
                        "subject": "'"$SUBJECT"'",
                        "bodyValues": {
                            "body1": {
                                "value": "'"$BODY_ESCAPED"'",
                                "charset": "utf-8"
                            }
                        },
                        "textBody": [{"partId": "body1", "type": "text/plain"}]
                    }
                }
            }, "c0"],
            ["EmailSubmission/set", {
                "accountId": "'"$ACCOUNT_ID"'",
                "create": {
                    "send1": {
                        "emailId": "#draft1",
                        "identityId": "'"$IDENTITY_ID"'",
                        "envelope": {
                            "mailFrom": {"email": "'"$FROM_EMAIL"'"},
                            "rcptTo": '"$RCPT_TO"'
                        }
                    }
                },
                "onSuccessUpdateEmail": {
                    "#send1": {
                        "mailboxIds/'"$DRAFTS_ID"'": null,
                        "mailboxIds/'"$SENT_ID"'": true,
                        "keywords/$draft": null
                    }
                }
            }, "c1"]
        ]
    }')

# Check for success
if echo "$RESPONSE" | grep -q '"undoStatus":"final"'; then
    echo "✅ Email sent successfully to: $TO_RAW"
    if [[ -n "${JMAP_CC:-}" ]]; then
        echo "   CC: $JMAP_CC"
    fi
    exit 0
elif echo "$RESPONSE" | grep -q '"created"'; then
    # Check if it was at least created
    if echo "$RESPONSE" | grep -q '"notCreated"'; then
        echo "❌ Failed to send email" >&2
        echo "$RESPONSE" >&2
        exit 1
    fi
    echo "✅ Email sent successfully to: $TO_RAW"
    exit 0
else
    echo "❌ Failed to send email" >&2
    echo "$RESPONSE" >&2
    exit 1
fi
