#!/bin/zsh
# Builds the release: Developer-ID signed + notarised app, a notarised DMG, and the Sparkle appcast (signed with the EdDSA key from the keychain).
# It does NOT publish anything: uploading to GitHub stays a separate step (the commands are printed at the end).
set -e
cd "$(dirname "$0")"
source ./update.conf; source ./VERSION
export SIGN_ID="${SIGN_ID:-Developer ID Application: Maik Klotz (FTJLR8JRNS)}"
PROFILE="${NOTARY_PROFILE:-Retromac}"
[[ "$GITHUB_REPO" == "OWNER/REPO" ]] && { echo "Set GITHUB_REPO in update.conf first."; exit 1; }
./notarize.sh   # Developer ID build + notarisation + stapling of the app
rm -rf release dmg-staging; mkdir -p release dmg-staging
cp -R ICQuel.app dmg-staging/; ln -s /Applications dmg-staging/Applications
DMG="release/ICQuel-$SHORT.dmg"
hdiutil create -volname "ICQuel" -srcfolder dmg-staging -ov -format UDZO "$DMG" >/dev/null
rm -rf dmg-staging
codesign --force --timestamp --sign "$SIGN_ID" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
[[ -f release-notes.html ]] && cp release-notes.html "release/ICQuel-$SHORT.html"   # shown in the update dialog
Vendor/Sparkle/bin/generate_appcast --account "$KEY_ACCOUNT" \
    --download-url-prefix "https://github.com/$GITHUB_REPO/releases/download/v$SHORT/" -o release/appcast.xml release/
echo
echo "Ready: $DMG and release/appcast.xml"
echo "Publish (manual):  gh release create v$SHORT \"$DMG\" release/appcast.xml --repo $GITHUB_REPO --title \"ICQuel $SHORT\" --notes-file release-notes.md"
echo "The app looks for:  https://github.com/$GITHUB_REPO/releases/latest/download/appcast.xml"
echo "Raise BUILD in VERSION for every release (Sparkle compares the build number)."
