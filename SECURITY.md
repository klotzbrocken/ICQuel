# Security Policy

## Supported versions

Only the latest release receives security fixes. Updates arrive through the in-app updater (app menu > Check for Updates…).

| Version | Supported |
|---------|-----------|
| 1.1.x   | yes       |
| 1.0.x   | no, please update |

## Reporting a vulnerability

Please report security problems **privately**, not in a public issue:

1. Open the **Security** tab of this repository and choose **Report a vulnerability** (GitHub private vulnerability reporting).
2. If that option is not shown, open a public issue titled "Security contact request" **without any details**. I will then arrange a private channel.

Please include the version (ICQuel > About), what you did, what happened, and, if you can, a minimal way to reproduce it. I aim to answer within a few days and to ship a fix in the next release; you will be credited unless you prefer not to be.

## What is in scope

ICQuel is a local macOS app. It has no server and no account. Relevant areas:

- Reading the Messages database and attachments (read-only, only conversations you import) and sending through the Messages app.
- API keys (stored in the macOS Keychain) and the text sent to the AI service you choose.
- The optional, experimental WhatsApp link (an unofficial open-source library; the Node.js runtime is downloaded once from nodejs.org and checked against its published checksum).
- Theme packs you import (plain folders / zip files), the update channel (Sparkle, EdDSA-signed) and the `icquel://status/…` URL scheme.

Out of scope: WhatsApp blocking accounts that use unofficial clients, the Giphy API key that ships inside the app (it is a shared, rate-limited key), and issues that need physical access to an unlocked Mac.
