#!/usr/bin/env bash
# Builds the double-click installer for Nepali Input.
#
#   ./installer/build_installer.sh
#
# Output: build/release/NepaliInput-1.0-Installer.dmg
#   The DMG contains "Install Nepali Input.pkg". Users open the DMG and
#   double-click the .pkg. No Terminal is needed.
#
# Optional code signing (removes the "unidentified developer" warning):
#   INSTALLER_SIGN_ID="Developer ID Installer: Your Name (TEAMID)" ./installer/build_installer.sh

set -euo pipefail
# Stop macOS from adding AppleDouble "._" files to the package payload.
export COPYFILE_DISABLE=1

VERSION="1.1"
APP_NAME="NepaliInput"
APP_BUNDLE="$APP_NAME.app"
PKG_ID="com.pradeeps.inputmethod.NepaliInput.installer"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build"
STAGE="$BUILD/installer-stage"
PKG_NAME="Install Nepali Input.pkg"
DMG_OUT="$BUILD/release/NepaliInput-$VERSION-Installer.dmg"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "Run this on macOS."
command -v swiftc >/dev/null || die "Install Xcode Command Line Tools: xcode-select --install"

# 1. Build the app.
log "Building $APP_BUNDLE"
make -C "$ROOT" build

# The registration helper is built universal and copied into the bundle by `make build`.
test -x "$BUILD/$APP_BUNDLE/Contents/Resources/register_input_source" || die "Helper missing from bundle"

# 3. Re-sign so the bundle (including the helper) has a valid signature.
codesign --force --deep --sign - --entitlements "$ROOT/Resources/NepaliInput.entitlements" "$BUILD/$APP_BUNDLE"

# 4. Stage the payload: the app goes to the system-wide input method folder.
log "Staging payload"
rm -rf "$STAGE"
mkdir -p "$STAGE/payload/Library/Input Methods"
# Copy without extended attributes. Attributes such as com.apple.provenance cannot be
# removed with xattr, and pkgbuild turns them into "._" entries inside the package.
ditto --noextattr --norsrc --noqtn "$BUILD/$APP_BUNDLE" "$STAGE/payload/Library/Input Methods/$APP_BUNDLE"
find "$STAGE/payload" -name '._*' -delete 2>/dev/null || true

# 5. Component plist: stop the installer from relocating the app onto an
#    existing copy (for example a development build in ~/Library/Input Methods).
COMPONENT_PLIST="$STAGE/component.plist"
pkgbuild --analyze --root "$STAGE/payload" "$COMPONENT_PLIST" >/dev/null
/usr/libexec/PlistBuddy -c "Delete :0:BundleIsRelocatable" "$COMPONENT_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :0:BundleIsRelocatable bool false" "$COMPONENT_PLIST"

# 6. Build the component package with the postinstall script.
chmod +x "$ROOT/installer/scripts/postinstall"
mkdir -p "$STAGE/pkg"
SIGN_ARGS=()
if [[ -n "${INSTALLER_SIGN_ID:-}" ]]; then
    SIGN_ARGS=(--sign "$INSTALLER_SIGN_ID")
fi
log "Building package"
pkgbuild --root "$STAGE/payload" \
    --component-plist "$COMPONENT_PLIST" \
    --scripts "$ROOT/installer/scripts" \
    --identifier "$PKG_ID" \
    --version "$VERSION" \
    --install-location "/" \
    ${SIGN_ARGS[@]+"${SIGN_ARGS[@]}"} \
    "$STAGE/pkg/$PKG_NAME"

# 7. Put the package in a DMG with a short instructions file.
log "Creating disk image"
DMG_STAGE="$STAGE/dmg"
mkdir -p "$DMG_STAGE"
cp "$STAGE/pkg/$PKG_NAME" "$DMG_STAGE/"
cat > "$DMG_STAGE/Read Me.txt" <<'EOF'
Nepali Input - Installation

1. Double-click "Install Nepali Input.pkg".
2. Click Continue and enter your Mac password when asked.
3. If macOS says it cannot be opened because the developer cannot be verified,
   right-click the file, choose Open, then click Open again.
4. Log out and back in once (Apple menu > Log Out).
5. Open System Settings > Keyboard > Input Sources and check that
   "Nepali Input" is listed. If not, click Edit..., then +, search for
   "Nepali Input", and add it.
6. Switch to it with the input menu in the menu bar (the ने icon) or Ctrl+Space.

To remove it, delete /Library/Input Methods/NepaliInput.app, remove
"Nepali Input" from Input Sources, and log out.
EOF

mkdir -p "$BUILD/release"
rm -f "$DMG_OUT"
hdiutil create -quiet -volname "Nepali Input $VERSION" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_OUT"

log "Done: $DMG_OUT"
