---
name: email-via-jmap
version: 2.0.0
description: Send and receive email via JMAP protocol (works over HTTPS). Use when checking inbox, reading messages, or sending emails. Supports Fastmail, Cyrus, Stalwart, and other JMAP providers. Does NOT work with Gmail, Outlook, ProtonMail, or Yahoo. Requires JMAP_TOKEN environment variable.
license: MIT
---

# Email via JMAP

Send and receive email using the JMAP protocol over HTTPS. Works in sandboxed environments where IMAP/SMTP ports are blocked.

## Discovery: Will This Work?

**Before attempting to use this skill, determine the user's email provider.**

### Step 1: Ask what email they use
Ask: "What email service do you use? (e.g., Gmail, Fastmail, Outlook, work email)"

### Step 2: Check compatibility

| Provider | JMAP Support | What to do |
|----------|--------------|------------|
| **Fastmail** | ✅ Yes | Use this skill. JMAP_HOST = `api.fastmail.com` |
| **Cyrus IMAP** | ✅ Yes | Use this skill. Ask for their server hostname |
| **Stalwart** | ✅ Yes | Use this skill. Ask for their server hostname |
| **Gmail** | ❌ No | Tell user: "Gmail doesn't support JMAP. You'd need a Gmail API skill." |
| **Outlook/M365** | ❌ No | Tell user: "Outlook doesn't support JMAP. You'd need a Microsoft Graph skill." |
| **ProtonMail** | ❌ No | Tell user: "ProtonMail doesn't support JMAP. You'd need ProtonMail Bridge." |
| **Yahoo** | ❌ No | Tell user: "Yahoo doesn't support JMAP." |
| **iCloud** | ❌ No | Tell user: "iCloud doesn't support JMAP." |
| **Work/Custom** | ⚠️ Maybe | Run `scripts/jmap-check.sh <their-mail-domain>` to test |

### Step 3: Test unknown providers
```bash
scripts/jmap-check.sh mail.example.com
```
This probes for JMAP endpoints and reports if the provider supports it.

## Requirements

Container environment variables:

| Variable | Required | Description |
|----------|----------|-------------|
| `JMAP_TOKEN` | Yes | API token from email provider |
| `JMAP_HOST` | No | JMAP hostname (default: `api.fastmail.com`) |

## Getting an API Token

### Fastmail
1. Log in to Fastmail web
2. Settings → Privacy & Security → Integrations → API tokens
3. Create new token, copy it
4. Set as `JMAP_TOKEN` environment variable

## Usage

### List inbox
```bash
scripts/jmap-list.sh [FOLDER]
```

### Read a message
```bash
scripts/jmap-read.sh <EMAIL_ID>
```

### Send an email
```bash
scripts/jmap-send.sh "to@example.com" "Subject" "Body text"
```

### Send to multiple recipients
```bash
scripts/jmap-send.sh "alice@example.com,bob@example.com" "Subject" "Body"
```

### Send with CC
```bash
JMAP_CC="manager@example.com" scripts/jmap-send.sh "to@example.com" "Subject" "Body"
```

### Mark emails as read
```bash
scripts/jmap-mark-read.sh <EMAIL_ID> [EMAIL_ID...]
```

### Workflow: Process only new emails
```bash
# 1. Get unread emails
scripts/jmap-unread.sh

# 2. Process each email...

# 3. Mark as read when done
scripts/jmap-mark-read.sh <EMAIL_ID>
```

## How It Works

1. Scripts fetch session info from `https://{JMAP_HOST}/jmap/session`
2. Account ID, mailbox IDs, and identity are auto-discovered
3. All communication happens over HTTPS (port 443)

## Security Notes

- Store `JMAP_TOKEN` in container environment, never in files
- JMAP tokens typically have full mailbox access — treat like a password
- Scripts fail gracefully if credentials are missing
