#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Applications/macOS TV Remote.app"
LEGACY_APP="$HOME/Applications/TV Remote.app"

pkill -x TVRemote >/dev/null 2>&1 || true
rm -rf "$APP" "$LEGACY_APP"
defaults delete local.eduardo.tvremote >/dev/null 2>&1 || true

if [[ "${1:-}" == "--purge" ]]; then
  rm -f "$ROOT/Shared/Resources/cert.der" "$ROOT/Shared/Resources/cert.p12"
  print "Removed the app, preferences, and local pairing identity."
else
  print "Removed the app and preferences."
  print "The local pairing identity was preserved. Use ./uninstall.sh --purge to remove it."
fi
