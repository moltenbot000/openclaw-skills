#!/bin/bash
# Check if a provider supports JMAP
# Usage: jmap-check.sh <hostname>
# Example: jmap-check.sh api.fastmail.com
#          jmap-check.sh mail.example.com

set -euo pipefail

if [[ -z "${1:-}" ]]; then
    echo "Usage: jmap-check.sh <hostname>" >&2
    echo "Example: jmap-check.sh api.fastmail.com" >&2
    exit 1
fi

HOST="$1"

echo "Checking JMAP support for: $HOST"
echo ""

# Known providers (fast path)
case "$HOST" in
    *fastmail.com)
        echo "✅ Fastmail supports JMAP"
        echo "JMAP_HOST: api.fastmail.com"
        echo "Get token: Settings → Privacy & Security → API tokens"
        exit 0
        ;;
    *gmail.com|*google.com)
        echo "❌ Gmail does NOT support JMAP"
        echo "Gmail uses its own API (Google Gmail API)."
        echo "A separate gmail-api skill would be needed."
        exit 1
        ;;
    *outlook.com|*office365.com|*microsoft.com|*hotmail.com|*live.com)
        echo "❌ Microsoft/Outlook does NOT support JMAP"
        echo "Microsoft uses Graph API for email access."
        echo "A separate microsoft-graph skill would be needed."
        exit 1
        ;;
    *protonmail.com|*proton.me)
        echo "❌ ProtonMail does NOT support JMAP"
        echo "ProtonMail requires ProtonMail Bridge for third-party access."
        exit 1
        ;;
    *yahoo.com|*aol.com)
        echo "❌ Yahoo/AOL does NOT support JMAP"
        exit 1
        ;;
    *icloud.com|*apple.com)
        echo "❌ iCloud does NOT support JMAP"
        exit 1
        ;;
esac

# Unknown provider - probe for JMAP
echo "Probing for JMAP endpoints..."

# Try JMAP session endpoint (requires auth but reveals support)
for path in "/jmap/session" "/.well-known/jmap"; do
    URL="https://${HOST}${path}"
    
    # Get both status code and check content type
    RESULT=$(curl -sf -w "\n%{http_code}\n%{content_type}" "$URL" 2>/dev/null || echo -e "\n000\n")
    HTTP_CODE=$(echo "$RESULT" | tail -2 | head -1)
    CONTENT_TYPE=$(echo "$RESULT" | tail -1)
    BODY=$(echo "$RESULT" | head -n -2)
    
    # 401/403 with JMAP in response suggests JMAP support
    if [[ "$HTTP_CODE" == "401" || "$HTTP_CODE" == "403" ]]; then
        echo "✅ Found JMAP endpoint at: $URL (requires authentication)"
        echo ""
        echo "This provider supports JMAP."
        echo "Set JMAP_HOST=$HOST"
        echo "User needs to get an API token from their provider."
        exit 0
    fi
    
    # 200 with JSON containing JMAP capabilities
    if [[ "$HTTP_CODE" == "200" && "$CONTENT_TYPE" == *"application/json"* ]]; then
        if echo "$BODY" | grep -q "urn:ietf:params:jmap"; then
            echo "✅ Found JMAP endpoint at: $URL"
            echo ""
            echo "This provider supports JMAP."
            echo "Set JMAP_HOST=$HOST"
            exit 0
        fi
    fi
done

echo "❌ No JMAP endpoint found at $HOST"
echo ""
echo "This provider may not support JMAP, or uses a different hostname."
echo ""
echo "Known JMAP providers:"
echo "  - Fastmail (api.fastmail.com)"
echo "  - Cyrus IMAP (self-hosted)"
echo "  - Stalwart Mail (self-hosted)"
echo "  - Apache James (self-hosted)"
echo ""
echo "If this is a work email, ask the user for their email server hostname"
echo "or check with their IT department if JMAP is supported."
exit 1
