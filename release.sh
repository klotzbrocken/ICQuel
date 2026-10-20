#!/bin/zsh
# Builds a release, zips it, signs it with the Sparkle EdDSA key and writes release/appcast.xml.
# It does NOT publish anything: uploading to GitHub stays a manual step (see the printed commands).
set -e
cd "$(dirname "$0")"
source ./update.conf; source ./VERSION
[[ "$GITHUB_REPO" == "OWNER/REPO" ]] && { echo "Set GITHUB_REPO in update.conf first."; exit 1; }
./notarize.sh   # Developer ID build + notarisation + stapling
mkdir -p release
ZIP="release/ICQuel-$SHORT.zip"
rm -f "$ZIP"; ditto -c -k --sequesterRsrc --keepParent ICQuel.app "$ZIP"
Vendor/Sparkle/bin/generate_appcast --account "$KEY_ACCOUNT" \
    --download-url-prefix "https://github.com/$GITHUB_REPO/releases/download/v$SHORT/" -o release/appcast.xml release/
echo
echo "Ready: $ZIP and release/appcast.xml"
echo "Publish (manual):  gh release create v$SHORT \"$ZIP\" release/appcast.xml --repo $GITHUB_REPO --title \"ICQuel $SHORT\""
echo "The app looks for:  https://github.com/$GITHUB_REPO/releases/latest/download/appcast.xml"
echo "Raise BUILD in VERSION for every release (Sparkle compares the build number)."
