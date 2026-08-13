# macOS TV Remote

A small, native macOS menu bar remote for Android TV and Google TV devices.

macOS TV Remote connects directly to your TV over the local network. It does not
require Shortcuts, Python, a browser, or a background daemon.

<p align="center">
  <img src="docs/images/product.png" alt="macOS TV Remote open from the menu bar" width="430">
</p>

## Features

- Native SwiftUI menu bar app
- Direction pad and OK button
- Home, Back, Power, and volume controls
- Play/pause and media navigation
- In-app pairing and re-pairing
- Editable TV IP address with automatic reconnection
- Optional button sound
- Persistent TLS connection while the remote is open
- No Dock icon or regular app window

## Requirements

- macOS 14 or later
- Xcode with the macOS SDK installed
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- An Android TV or Google TV device on the same local network
- A client certificate and private key for the initial build

The remote protocol uses TCP port `6466`. Pairing uses TCP port `6467`.

## Setup

Install XcodeGen:

```bash
brew install xcodegen
```

Place your local pairing material in `Shared/Resources`:

```text
Shared/Resources/cert.der
Shared/Resources/cert.p12
```

The PKCS#12 file must use the password `tvremote`. Certificate files are ignored
by Git and must never be committed.

If you already have PEM files from `tvctl`, convert them with:

```bash
mkdir -p Shared/Resources

openssl x509 \
  -in ~/.local/share/tvctl/cert.pem \
  -outform DER \
  -out Shared/Resources/cert.der

openssl pkcs12 -export \
  -inkey ~/.local/share/tvctl/key.pem \
  -in ~/.local/share/tvctl/cert.pem \
  -out Shared/Resources/cert.p12 \
  -passout pass:tvremote
```

Generate the Xcode project and build the app:

```bash
xcodegen generate
xcodebuild \
  -project TVRemote.xcodeproj \
  -scheme TVRemote \
  -configuration Debug \
  build
```

You can also open `TVRemote.xcodeproj`, select the `TVRemote` scheme and run it
on **My Mac**. If Xcode requests signing credentials, select your Development
Team for the app target.

## Usage

1. Launch the app and select the remote icon in the macOS menu bar.
2. Open Settings using the gear icon.
3. Enter the local IPv4 address of your TV.
4. Use the link button to pair or re-pair the Mac with the TV.
5. Enter the six-character code shown on the TV when prompted.

The IP address and sound preference are stored locally in `UserDefaults`.

## Architecture

The app uses SwiftUI's `MenuBarExtra` for the interface and communicates with the
TV through the vendored
[`AndroidTVRemoteControl`](https://github.com/odyshewroman/AndroidTVRemoteControl)
Swift package.

```text
MenuBarExtra
    -> RemoteControlModel
    -> TVRemoteSession actor
    -> AndroidTVRemoteControl
    -> TLS connection to the TV
```

`TVRemoteSession` serializes commands and keeps the TLS connection alive while
the panel is open, then disconnects after a short idle period.

## Project Structure

```text
TVRemote/              Menu bar UI, app lifecycle, and app icon
Shared/                TV configuration and remote session
Shared/Resources/      Local certificates (ignored by Git)
Vendor/                Android TV remote Swift package
project.yml            XcodeGen project definition
```

## Privacy

macOS TV Remote communicates only with the TV address configured in the app. It
does not include analytics, tracking, or cloud services.

## License

No license has been added to this repository yet.
