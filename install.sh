#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PAIR_DIR="$HOME/.local/share/tvctl"
CERT_PEM="$PAIR_DIR/cert.pem"
KEY_PEM="$PAIR_DIR/key.pem"
HOST_FILE="$PAIR_DIR/host"
VENDOR="$ROOT/Vendor/AndroidTVRemoteControl"
RES="$ROOT/Shared/Resources"

echo "→ TV Remote nativo (Swift only)"

for f in "$CERT_PEM" "$KEY_PEM" "$HOST_FILE"; do
  [[ -f "$f" ]] || {
    echo "❌ Falta $f"
    echo "   Esta primera migración reutiliza el pairing que ya hiciste con tvctl."
    exit 1
  }
done

command -v xcodegen >/dev/null || {
  echo "❌ Falta XcodeGen: brew install xcodegen"
  exit 1
}

xcodebuild -version >/dev/null 2>&1 || {
  echo "❌ Xcode completo no está configurado."
  exit 1
}

# Si llegaste a probar el bridge Python anterior, lo eliminamos.
OLD_PLIST="$HOME/Library/LaunchAgents/local.tvremote.bridge.plist"
if [[ -f "$OLD_PLIST" ]]; then
  launchctl bootout "gui/$(id -u)" "$OLD_PLIST" 2>/dev/null || true
  rm -f "$OLD_PLIST"
fi
rm -f "$PAIR_DIR/tvbridge.py"

mkdir -p "$RES"

echo "→ Migrando el certificado ya emparejado a formatos nativos…"
/usr/bin/openssl x509 \
  -in "$CERT_PEM" \
  -outform DER \
  -out "$RES/cert.der"

/usr/bin/openssl pkcs12 -export \
  -inkey "$KEY_PEM" \
  -in "$CERT_PEM" \
  -out "$RES/cert.p12" \
  -passout pass:tvremote

HOST="$(tr -d '[:space:]' < "$HOST_FILE")"
cat > "$ROOT/Shared/TVConfig.swift" <<EOF
import Foundation

enum TVConfig {
    static let host = "$HOST"
}
EOF

if [[ ! -d "$VENDOR/.git" ]]; then
  echo "→ Descargando AndroidTVRemoteControl (MIT)…"
  rm -rf "$VENDOR"
  git clone --depth 1 \
    https://github.com/odyshewroman/AndroidTVRemoteControl.git \
    "$VENDOR"
fi

# El proyecto upstream declara iOS en Package.swift aunque su implementación
# usa Foundation/Network/Security y es portable. Añadimos macOS al paquete local.
if ! grep -q '\.macOS(' "$VENDOR/Package.swift"; then
  /usr/bin/perl -0pi -e 's/platforms: \[\.iOS\(\.v13\)\],/platforms: [.iOS(.v13), .macOS(.v13)],/' "$VENDOR/Package.swift"
else
  /usr/bin/perl -0pi -e 's/\.macOS\(\.v14\)/.macOS(.v13)/g' "$VENDOR/Package.swift"
fi

grep -q '\.macOS(' "$VENDOR/Package.swift" || {
  echo "❌ No pude parchear Package.swift automáticamente."
  exit 1
}

cd "$ROOT"
echo "→ Generando proyecto Xcode…"
xcodegen generate

echo
echo "✅ Proyecto 100% Swift generado."
echo "   TV: $HOST"
echo "   Python/Shortcuts NO se usan en runtime."
echo
echo "→ Abriendo Xcode…"
open "$ROOT/TVRemote.xcodeproj"

echo
echo "En Xcode:"
echo "  1. Scheme: TVRemote"
echo "  2. Destination: My Mac"
echo "  3. ⌘R"
echo "  4. Si pide Signing, elegí tu Team en ambos targets."
echo
echo "Después: click hora → Edit Widgets → TV Remote → widget mediano."
