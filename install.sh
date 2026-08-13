#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")" && pwd)"
RESOURCES="$ROOT/Shared/Resources"
DER_CERT="$RESOURCES/cert.der"
P12_CERT="$RESOURCES/cert.p12"
BUILD_ROOT="$ROOT/build"
BUILT_APP="$BUILD_ROOT/DerivedData/Build/Products/Release/TVRemote.app"
INSTALL_DIR="$HOME/Applications"
INSTALLED_APP="$INSTALL_DIR/macOS TV Remote.app"
LEGACY_APP="$INSTALL_DIR/TV Remote.app"

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

command -v xcodebuild >/dev/null 2>&1 || fail "Xcode is required. Install it from the Mac App Store."
command -v openssl >/dev/null 2>&1 || fail "OpenSSL is required but was not found."

if ! xcodebuild -version >/dev/null 2>&1; then
  fail "Select a full Xcode installation with: sudo xcode-select -s /Applications/Xcode.app"
fi

mkdir -p "$RESOURCES" "$INSTALL_DIR"

if [ ! -f "$DER_CERT" ] || [ ! -f "$P12_CERT" ]; then
  printf '%s\n' "Creating a private pairing identity for this Mac..."
  TEMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TEMP_DIR"' EXIT

  openssl req \
    -x509 \
    -newkey rsa:2048 \
    -sha256 \
    -nodes \
    -keyout "$TEMP_DIR/key.pem" \
    -out "$TEMP_DIR/cert.pem" \
    -days 3650 \
    -subj "/CN=macOS TV Remote" \
    >/dev/null 2>&1

  openssl x509 \
    -in "$TEMP_DIR/cert.pem" \
    -outform DER \
    -out "$DER_CERT"

  openssl pkcs12 \
    -export \
    -inkey "$TEMP_DIR/key.pem" \
    -in "$TEMP_DIR/cert.pem" \
    -out "$P12_CERT" \
    -passout pass:tvremote

fi

chmod 600 "$DER_CERT" "$P12_CERT"

printf '%s\n' "Building macOS TV Remote..."
xcodebuild \
  -quiet \
  -project "$ROOT/TVRemote.xcodeproj" \
  -scheme TVRemote \
  -configuration Release \
  -derivedDataPath "$BUILD_ROOT/DerivedData" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  build

[ -d "$BUILT_APP" ] || fail "The build completed without producing TVRemote.app."

printf 'Installing in %s...\n' "$INSTALL_DIR"
pkill -x TVRemote >/dev/null 2>&1 || true
rm -rf "$INSTALLED_APP" "$LEGACY_APP"
ditto "$BUILT_APP" "$INSTALLED_APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f -R -trusted "$INSTALLED_APP"

open "$INSTALLED_APP"

printf '\n%s\n' "macOS TV Remote is installed."
printf '%s\n' "Open the menu bar remote, enter your TV IP in Settings, and select Pair."
