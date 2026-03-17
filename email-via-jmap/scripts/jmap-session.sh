#!/bin/bash
# Fetch JMAP session info (used internally by other scripts)
# Outputs JSON session data

set -euo pipefail

JMAP_HOST="${JMAP_HOST:-api.fastmail.com}"

if [[ -z "${JMAP_TOKEN:-}" ]]; then
    echo "ERROR: JMAP_TOKEN environment variable not set" >&2
    echo "Get an API token from your email provider and set it in container config." >&2
    exit 1
fi

curl -sf -H "Authorization: Bearer ${JMAP_TOKEN}" \
    "https://${JMAP_HOST}/jmap/session"
