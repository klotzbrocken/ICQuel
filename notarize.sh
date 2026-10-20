#!/bin/zsh
# Builds with the Developer ID certificate, notarises with Apple (notarytool keychain profile "Retromac") and staples the ticket.
set -e
cd "$(dirname "$0")"
export SIGN_ID="${SIGN_ID:-Developer ID Application: Maik Klotz (FTJLR8JRNS)}"
PROFILE="${NOTARY_PROFILE:-Retromac}"
./build.sh
codesign --verify --deep --strict --verbose=2 ICQuel.app
ditto -c -k --keepParent ICQuel.app /tmp/ICQuel-notarize.zip
xcrun notarytool submit /tmp/ICQuel-notarize.zip --keychain-profile "$PROFILE" --wait
xcrun stapler staple ICQuel.app
spctl -a -vv -t exec ICQuel.app
echo "notarised and stapled: ICQuel.app"
