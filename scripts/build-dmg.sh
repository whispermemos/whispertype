#!/bin/bash

# Builds a Developer ID-signed, notarized WhisperType.dmg for GitHub releases.
# Archives the Release scheme, exports it for Developer ID, notarizes and staples the app,
# then wraps it in a DMG with an Applications shortcut and notarizes and staples the DMG too.
#
# One-time setup: store App Store Connect API key credentials for notarytool in the Keychain:
#   xcrun notarytool store-credentials whispertype-notary --key AuthKey_XXX.p8 --key-id XXX --issuer XXX
# Output: build/release/WhisperType.dmg

set -euo pipefail

cd "$(dirname "$0")/.."

NOTARY_PROFILE="${NOTARY_PROFILE:-whispertype-notary}"
OUT="build/release"
APP="$OUT/WhisperType.app"
DMG="$OUT/WhisperType.dmg"

rm -rf "$OUT"
mkdir -p "$OUT"

echo "==> Archiving"
xcodebuild archive \
    -project WhisperType.xcodeproj \
    -scheme Release \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$OUT/WhisperType.xcarchive" \
    -allowProvisioningUpdates \
    -quiet

echo "==> Exporting for Developer ID"
cat > "$OUT/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF
xcodebuild -exportArchive \
    -archivePath "$OUT/WhisperType.xcarchive" \
    -exportPath "$OUT" \
    -exportOptionsPlist "$OUT/ExportOptions.plist" \
    -allowProvisioningUpdates \
    -quiet

echo "==> Notarizing app"
ditto -c -k --keepParent "$APP" "$OUT/WhisperType.zip"
xcrun notarytool submit "$OUT/WhisperType.zip" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"

echo "==> Creating DMG"
mkdir "$OUT/dmg"
cp -R "$APP" "$OUT/dmg/"
ln -s /Applications "$OUT/dmg/Applications"
hdiutil create -volname WhisperType -srcfolder "$OUT/dmg" -format UDZO -ov "$DMG"
codesign --sign "Developer ID Application" --timestamp "$DMG"

echo "==> Notarizing DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"

echo "==> Verifying"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"
spctl --assess --type execute --verbose "$APP"

echo "==> Done: $DMG"
