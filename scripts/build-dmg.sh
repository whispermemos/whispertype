#!/bin/bash

# Builds a Developer ID-signed, notarized WhisperType.dmg for GitHub releases.
# Archives the Release scheme, exports it for Developer ID, notarizes and staples the app,
# then wraps it in a DMG installer window (background with arrow, app and Applications icons)
# and notarizes and staples the DMG too. The background art lives in scripts/dmg/.
#
# Needs create-dmg: brew install create-dmg
# One-time setup: store App Store Connect API key credentials for notarytool in the Keychain:
#   xcrun notarytool store-credentials whispertype-notary --key AuthKey_XXX.p8 --key-id XXX --issuer XXX
# Output: build/release/WhisperType.dmg

set -euo pipefail

cd "$(dirname "$0")/.."

command -v create-dmg >/dev/null || { echo "create-dmg is missing. Run: brew install create-dmg"; exit 1; }

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
    -derivedDataPath build/DerivedData \
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
# One TIFF holding both @1x and @2x, so the background stays sharp on Retina displays.
tiffutil -cathidpicheck scripts/dmg/background.png scripts/dmg/background@2x.png -out "$OUT/background.tiff"
# Icon positions match the arrow in scripts/dmg/draw-background.swift. The window is 32pt
# taller than the 400pt background to make room for the title bar.
create-dmg \
    --volname WhisperType \
    --volicon "$APP/Contents/Resources/AppIcon.icns" \
    --background "$OUT/background.tiff" \
    --window-size 660 432 \
    --icon-size 128 \
    --icon WhisperType.app 170 180 \
    --hide-extension WhisperType.app \
    --app-drop-link 490 180 \
    "$DMG" "$OUT/dmg"
codesign --sign "Developer ID Application" --timestamp "$DMG"

echo "==> Notarizing DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"

echo "==> Verifying"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"
spctl --assess --type execute --verbose "$APP"

echo "==> Done: $DMG"
