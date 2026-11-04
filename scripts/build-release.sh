#!/bin/zsh
# build-release.sh
# Krasip
# Builds, signs, notarizes and staples Krasip.app, then proves it opens on any Mac.

set -euo pipefail
cd "$(dirname "$0")/.."

KEYCHAIN_PROFILE=krasip-notary
VERSION=$(sed -n 's/^MARKETING_VERSION = //p' Config/Base.xcconfig | tr -d ' ')
ARCHIVE=build/Krasip.xcarchive
EXPORT_DIR=build/export
APP=build/Krasip.app
ZIP=build/Krasip-$VERSION.zip

step() { print -P "\n%F{blue}==%f $1" }
fail() { print -P "\n%F{red}==%f $1"; exit 1 }

[[ -n $VERSION ]] || fail "No MARKETING_VERSION in Config/Base.xcconfig."
identities=$(security find-identity -v -p codesigning)
print -r -- "$identities" | grep -q "Developer ID Application" \
  || fail "No Developer ID Application certificate on this Mac. Make one in Xcode, Settings, Accounts, Manage Certificates."
xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" >/dev/null 2>&1 \
  || fail "The '$KEYCHAIN_PROFILE' keychain profile is missing or rejected. Run: xcrun notarytool store-credentials $KEYCHAIN_PROFILE"

# A leftover app from an earlier run can be shipped by mistake, so nothing survives into this one.
step "Clearing the last build"
rm -rf "$ARCHIVE" "$EXPORT_DIR" "$APP" build/Krasip-*.zip(N)

step "Archiving $VERSION"
xcodebuild archive \
  -project Krasip.xcodeproj \
  -scheme Krasip \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  | grep -E "error:|warning:|ARCHIVE" || true
[[ -d $ARCHIVE ]] || fail "No archive was produced."

step "Exporting with the Developer ID certificate"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist Config/ExportOptions.plist \
  -exportPath "$EXPORT_DIR" \
  | grep -E "error:|EXPORT" || true
[[ -d $EXPORT_DIR/Krasip.app ]] || fail "The export produced no app."
cp -R "$EXPORT_DIR/Krasip.app" "$APP"

step "Checking the signature before Apple sees it"
codesign --verify --strict --verbose=2 "$APP"
signature=$(codesign -dvvv "$APP" 2>&1)
print -r -- "$signature" | grep -q "Authority=Developer ID Application" \
  || fail "Not signed with a Developer ID certificate. Apple would reject it."
print -r -- "$signature" | grep -q "flags=.*runtime" \
  || fail "The hardened runtime is off. Notarizing needs it on."

step "Sending it to Apple"
# ditto keeps the signature intact; a plain zip does not.
ditto -c -k --keepParent "$APP" "$ZIP"
submission=$(xcrun notarytool submit "$ZIP" --keychain-profile "$KEYCHAIN_PROFILE" --wait 2>&1) || true
print -r -- "$submission"
if ! print -r -- "$submission" | grep -q "status: Accepted"; then
  id=$(print -r -- "$submission" | sed -n 's/^ *id: //p' | head -1)
  [[ -n $id ]] && xcrun notarytool log "$id" --keychain-profile "$KEYCHAIN_PROFILE" || true
  fail "Apple did not accept this build. The reasons are above."
fi

step "Stapling Apple's stamp onto the app"
xcrun stapler staple "$APP"
# The zip Apple received has no staple, so the one we ship is rebuilt from the stapled app.
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

step "Proving it opens on another Mac"
xcrun stapler validate "$APP"
assessment=$(spctl -a -vvv -t exec "$APP" 2>&1) || true
print -r -- "$assessment"
print -r -- "$assessment" | grep -q "source=Notarized Developer ID" \
  || fail "Gatekeeper does not see this as notarized. Do not ship this build."

step "Done"
print -r -- "Ship this file: $(pwd)/$ZIP"
print -r -- "It opens on any Mac with a double click. No right-click trick needed."
