#!/bin/zsh
# Builds ICQ99b.app (native macOS, no Xcode project needed). Usage: ./build.sh
set -e
cd "$(dirname "$0")"
APP=ICQuel.app
rm -rf $APP ICQ99b.app; mkdir -p $APP/Contents/MacOS $APP/Contents/Resources
source ./update.conf; source ./VERSION
for ARCH in arm64 x86_64; do   # universal binary
    swiftc -O -swift-version 5 -target $ARCH-apple-macos13.0 Sources/*.swift -o /tmp/icquel-$ARCH -framework SwiftUI -framework AppKit \
        -F Vendor/Sparkle -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks
done
lipo -create /tmp/icquel-arm64 /tmp/icquel-x86_64 -output $APP/Contents/MacOS/ICQuel
mkdir -p $APP/Contents/Frameworks && ditto Vendor/Sparkle/Sparkle.framework $APP/Contents/Frameworks/Sparkle.framework
cp -R assets-own/img $APP/Contents/Resources/img
cp -R assets-own/sounds $APP/Contents/Resources/sounds
cp Vendor/Sparkle/LICENSE $APP/Contents/Resources/Sparkle-LICENSE.txt   # MIT licence of the bundled Sparkle framework
cp assets-own/icon.png $APP/Contents/Resources/icon.png   # shown as the Dock icon (large, cut out)
# app icon (own artwork, tools/gen_assets.py)
python3 - <<'E'
from PIL import Image
import os
os.makedirs('/tmp/icquel.iconset',exist_ok=True)
im=Image.open('assets-own/icon.png').convert('RGBA')
for b in (16,32,128,256,512):
    for k in (1,2):
        im.resize((b*k,b*k),Image.LANCZOS).save(f'/tmp/icquel.iconset/icon_{b}x{b}'+('@2x' if k==2 else '')+'.png')
E
iconutil -c icns /tmp/icquel.iconset -o $APP/Contents/Resources/AppIcon.icns
cat > $APP/Contents/Info.plist <<'E'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>ICQuel</string>
<key>CFBundleDisplayName</key><string>ICQuel</string>
<key>CFBundleIdentifier</key><string>local.icquel.app</string>
<key>CFBundleExecutable</key><string>ICQuel</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>__SHORT__</string>
<key>CFBundleVersion</key><string>__BUILD__</string>
<key>SUFeedURL</key><string>https://github.com/__REPO__/releases/latest/download/appcast.xml</string>
<key>SUPublicEDKey</key><string>__KEY__</string>
<key>SUEnableAutomaticChecks</key><true/>
<key>SUScheduledCheckInterval</key><integer>86400</integer>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppleEventsUsageDescription</key><string>Used only by the optional Messages bridge to send messages through the Messages app.</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
E
sed -i '' "s|__SHORT__|$SHORT|; s|__BUILD__|$BUILD|; s|__REPO__|$GITHUB_REPO|; s|__KEY__|$SU_PUBLIC_KEY|" $APP/Contents/Info.plist
if [[ -n "$SIGN_ID" ]]; then   # Developer ID + hardened runtime (needed for notarisation; privacy grants then survive updates)
    F=$APP/Contents/Frameworks/Sparkle.framework/Versions/B
    for x in $F/XPCServices/*.xpc $F/Autoupdate $F/Updater.app; do [[ -e $x ]] && codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$x"; done
    codesign --force --options runtime --timestamp --sign "$SIGN_ID" $APP/Contents/Frameworks/Sparkle.framework
    codesign --force --options runtime --timestamp --entitlements ICQuel.entitlements --sign "$SIGN_ID" $APP
else
    codesign --force --deep --sign - $APP/Contents/Frameworks/Sparkle.framework
    # stable designated requirement: macOS privacy grants (Full Disk Access, Automation) survive rebuilds
    codesign --force --sign - --requirements '=designated => identifier "local.icquel.app"' $APP
fi
echo "built $APP"
