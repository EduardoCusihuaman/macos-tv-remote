# TV Remote Native

Control de Google TV para macOS, sin Shortcuts, sin Python en runtime y sin daemon.

## Arquitectura

WidgetKit `Button(intent:)`
→ `AppIntent`
→ Swift
→ `AndroidTVRemoteControl`
→ TLS directo a la TV (`:6466`)

La app contenedora también puede hacer Pair/Re-pair nativamente por `:6467`.

## Instalación

Requisitos:

- Xcode completo
- XcodeGen
- el pairing actual de `tvctl` (solo para migrar el certificado una vez)

```bash
brew install xcodegen
chmod +x install.sh
./install.sh
```

El instalador:

1. convierte `~/.local/share/tvctl/cert.pem` + `key.pem` a `cert.der`/`cert.p12`;
2. lee la IP guardada;
3. descarga la librería Swift `AndroidTVRemoteControl`;
4. añade macOS a su `Package.swift` local;
5. genera y abre `TVRemote.xcodeproj`.

## Xcode

1. Scheme: `TVRemote`
2. Destination: `My Mac`
3. `⌘R`
4. Si Signing lo pide, elegí tu Development Team en ambos targets.

La app tiene **Probar Home** y **Pair / Re-pair**.

## Widget

Click en la hora → **Edit Widgets** → **TV Remote** → widget mediano.

## Borrar Python después

Solo cuando app + widget funcionen:

```bash
chmod +x cleanup-old-tvctl.sh
./cleanup-old-tvctl.sh
```

Eso elimina `~/.local/bin/tvctl` y `~/.local/share/tvctl`.
