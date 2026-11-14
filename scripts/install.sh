#!/usr/bin/env bash
# Nepali Input — one-command installer.
#
#   ./scripts/install.sh              build, install, register and enable
#   ./scripts/install.sh --uninstall  remove the app and disable its input source
#
# Installs to ~/Library/Input Methods (the only location macOS scans for input
# methods), clears quarantine, re-signs, registers with Launch Services and
# Text Input Services, and enables the input source.

set -euo pipefail

APP_NAME="NepaliInput"
APP_BUNDLE="$APP_NAME.app"
BUNDLE_ID="com.pradeeps.inputmethod.NepaliInput"
INPUT_SOURCE_ID="$BUNDLE_ID"
DEST_DIR="$HOME/Library/Input Methods"
DEST_APP="$DEST_DIR/$APP_BUNDLE"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_APP="$ROOT/build/$APP_BUNDLE"
ENTITLEMENTS="$ROOT/Resources/NepaliInput.entitlements"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
HELPER_SRC="$ROOT/scripts/register_input_source.swift"
HELPER_BIN="$ROOT/build/register_input_source"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

stop_running() {
    pkill -x "$APP_NAME" 2>/dev/null || true
    sleep 1
}

disable_source() {
    # Remove the input source from the user's enabled list, if the helper exists.
    if [[ -x "$HELPER_BIN" ]]; then
        "$HELPER_BIN" --disable "$DEST_APP" "$INPUT_SOURCE_ID" >/dev/null 2>&1 || true
    fi
}

uninstall() {
    log "Uninstalling $APP_NAME"
    disable_source
    stop_running
    rm -rf "$DEST_APP"
    log "Removed $DEST_APP"
    warn "Log out and back in to finish removing it from Input Sources."
    exit 0
}

[[ "$(uname -s)" == "Darwin" ]] || die "This installer only runs on macOS."
[[ "${1:-}" == "--uninstall" ]] && uninstall
[[ -n "${1:-}" ]] && die "Unknown option: $1"

command -v swiftc >/dev/null || die "swiftc not found. Install Xcode Command Line Tools: xcode-select --install"
[[ "$(uname -m)" == "arm64" ]] || warn "Build targets arm64; this Mac is $(uname -m) and the app may not load."

# 1. Build the app bundle.
log "Building $APP_BUNDLE"
make -C "$ROOT" build

# 2. Compile the registration helper.
log "Compiling registration helper"
swiftc -O "$HELPER_SRC" -o "$HELPER_BIN" -framework Carbon -framework Foundation

# 3. Install into ~/Library/Input Methods.
log "Installing to $DEST_DIR"
mkdir -p "$DEST_DIR"
stop_running
rm -rf "$DEST_APP"
ditto "$BUILD_APP" "$DEST_APP"

# 4. Clear quarantine and sign for this machine.
xattr -dr com.apple.quarantine "$DEST_APP" 2>/dev/null || true
codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$DEST_APP"

# 5. Register with Launch Services, then with Text Input Services.
log "Registering input method"
[[ -x "$LSREGISTER" ]] && "$LSREGISTER" -f "$DEST_APP" >/dev/null 2>&1 || true
if ! "$HELPER_BIN" "$DEST_APP" "$INPUT_SOURCE_ID"; then
    warn "Automatic enable failed."
    warn "Log out and back in, then add it manually: System Settings → Keyboard → Input Sources → Edit → + → Nepali Input."
    exit 1
fi

log "Installed and enabled: $DEST_APP"
echo ""
echo "  Switch to it with the input menu (ने in the menu bar) or Ctrl+Space."
echo "  If it does not appear in System Settings → Keyboard → Input Sources,"
echo "  log out and back in once. macOS scans input methods at login."
