import AppKit
import AVFoundation
import Observation
import SwiftUI

@main
struct TVRemoteApp: App {
    @State private var remote = RemoteControlModel()

    var body: some Scene {
        MenuBarExtra {
            RemotePanel(remote: remote)
        } label: {
            Image(systemName: "av.remote.fill")
                .accessibilityLabel("TV Remote")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
@Observable
private final class RemoteControlModel {
    enum ConnectionState {
        case idle
        case connecting
        case connected
        case failed
    }

    enum HostUpdateState {
        case idle
        case updating
        case success
        case failed(String)
    }

    private(set) var state: ConnectionState = .idle
    private(set) var hostUpdateState: HostUpdateState = .idle
    var host = TVConfig.host
    var soundEnabled = TVConfig.soundEnabled {
        didSet { TVConfig.soundEnabled = soundEnabled }
    }

    private let sender = TVOneShotSender()
    @ObservationIgnored private let clickPlayer = ClickPlayer()

    var status: String {
        switch state {
        case .idle: return "Lista"
        case .connecting: return "Conectando"
        case .connected: return "Conectada"
        case .failed: return "Sin conexión"
        }
    }

    var statusColor: Color {
        switch state {
        case .connected: return .green
        case .failed: return .red
        case .idle, .connecting: return .secondary
        }
    }

    func activate() {
        state = .connecting
        Task {
            await sender.observeConnection { [weak self] connected in
                Task { @MainActor in
                    guard let self else { return }
                    if connected {
                        self.state = .connected
                    } else if self.state == .connected {
                        self.state = .failed
                    }
                }
            }

            do {
                try await sender.activate()
                state = .connected
            } catch {
                state = .failed
            }
        }
    }

    func deactivate() {
        Task { await sender.deactivate() }
    }

    func send(_ command: TVCommand) {
        if soundEnabled {
            clickPlayer.play()
        }

        Task {
            do {
                try await sender.send(command)
                state = .connected
            } catch {
                state = .failed
            }
        }
    }

    func saveHost(_ value: String) {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidIPv4(normalized) else {
            hostUpdateState = .failed("Ingresá una dirección IPv4 válida")
            return
        }

        guard normalized != host else { return }

        host = normalized
        TVConfig.host = normalized
        hostUpdateState = .updating
        state = .connecting

        Task {
            do {
                try await sender.reconnect()
                state = .connected
                hostUpdateState = .success
            } catch {
                state = .failed
                hostUpdateState = .failed("No se pudo conectar a esta IP")
            }
        }
    }

    func resetHostUpdateState() {
        hostUpdateState = .idle
    }

    private static func isValidIPv4(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 4 && parts.allSatisfy { part in
            guard let number = Int(part), number >= 0, number <= 255 else { return false }
            return String(number) == part
        }
    }
}

private final class ClickPlayer {
    private let player: AVAudioPlayer?

    init() {
        player = try? AVAudioPlayer(data: Self.makeClick())
        player?.volume = 0.18
        player?.prepareToPlay()
    }

    func play() {
        player?.currentTime = 0
        player?.play()
    }

    private static func makeClick() -> Data {
        let sampleRate = 22_050
        let sampleCount = Int(Double(sampleRate) * 0.02)
        var samples = Data(capacity: sampleCount * 2)

        for index in 0..<sampleCount {
            let time = Double(index) / Double(sampleRate)
            let envelope = exp(-time * 230)
            let wave = sin(2 * .pi * 2_400 * time) * envelope
            var sample = Int16(wave * Double(Int16.max) * 0.7).littleEndian
            withUnsafeBytes(of: &sample) { samples.append(contentsOf: $0) }
        }

        var data = Data("RIFF".utf8)
        append(UInt32(36 + samples.count), to: &data)
        data.append(Data("WAVEfmt ".utf8))
        append(UInt32(16), to: &data)
        append(UInt16(1), to: &data)
        append(UInt16(1), to: &data)
        append(UInt32(sampleRate), to: &data)
        append(UInt32(sampleRate * 2), to: &data)
        append(UInt16(2), to: &data)
        append(UInt16(16), to: &data)
        data.append(Data("data".utf8))
        append(UInt32(samples.count), to: &data)
        data.append(samples)
        return data
    }

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var value = value.littleEndian
        withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
    }
}

private struct RemotePanel: View {
    let remote: RemoteControlModel
    @StateObject private var pairing = TVPairingModel()
    @State private var showsSettings = false
    @State private var pin = ""
    @State private var host = TVConfig.host
    @FocusState private var pinIsFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            header

            HStack(alignment: .center, spacing: 8) {
                VolumeControl(remote: remote)
                DirectionPad(remote: remote)
            }

            HStack(spacing: 5) {
                RemoteKeyButton(remote: remote, command: .back, symbol: "chevron.backward", label: "Atrás")
                RemoteKeyButton(remote: remote, command: .home, symbol: "house.fill", label: "Inicio")
                RemoteKeyButton(remote: remote, command: .power, symbol: "power", label: "Encender o apagar", role: .destructive)
            }

            PlaybackControl(remote: remote)

            if showsSettings {
                PairingControl(
                    pairing: pairing,
                    remote: remote,
                    host: $host,
                    pin: $pin,
                    pinIsFocused: $pinIsFocused
                )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

        }
        .padding(9)
        .frame(width: 230)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { remote.activate() }
        .onDisappear { remote.deactivate() }
        .onChange(of: pairing.waitingForPIN) { _, waiting in
            pinIsFocused = waiting
        }
        .onChange(of: pin) { _, value in
            let normalized = String(value.uppercased().prefix(6))
            if pin != normalized { pin = normalized }
        }
        .animation(.snappy, value: showsSettings)
        .animation(.snappy, value: pairing.waitingForPIN)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "av.remote.fill")
                .font(.system(size: 16, weight: .semibold))

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(TVConfig.name)
                        .font(.headline)

                    Circle()
                        .fill(remote.statusColor)
                        .frame(width: 7, height: 7)
                        .help(remote.status)
                        .accessibilityLabel(remote.status)
                }

                Text(remote.host)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showsSettings.toggle()
                if showsSettings {
                    host = remote.host
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 10, weight: .regular))
                    .frame(width: 17, height: 16)
            }
            .buttonStyle(.plain)
            .foregroundStyle(showsSettings ? Color.accentColor.opacity(0.75) : Color.secondary.opacity(0.6))
            .help("Configuración")
            .pointingHandCursor()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 10, weight: .regular))
                    .frame(width: 17, height: 16)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.secondary.opacity(0.6))
            .help("Salir")
            .pointingHandCursor()
        }
    }
}

private struct DirectionPad: View {
    let remote: RemoteControlModel

    var body: some View {
        Grid(horizontalSpacing: 3, verticalSpacing: 3) {
            GridRow {
                padPlaceholder
                RemoteKeyButton(remote: remote, command: .up, symbol: "chevron.up", label: "Arriba", shape: .square)
                padPlaceholder
            }
            GridRow {
                RemoteKeyButton(remote: remote, command: .left, symbol: "chevron.left", label: "Izquierda", shape: .square)
                RemoteKeyButton(
                    remote: remote,
                    command: .ok,
                    label: "Aceptar",
                    text: "OK",
                    shape: .square,
                    emphasized: true
                )
                RemoteKeyButton(remote: remote, command: .right, symbol: "chevron.right", label: "Derecha", shape: .square)
            }
            GridRow {
                padPlaceholder
                RemoteKeyButton(remote: remote, command: .down, symbol: "chevron.down", label: "Abajo", shape: .square)
                padPlaceholder
            }
        }
        .padding(3)
        .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var padPlaceholder: some View {
        Color.clear
            .frame(width: 34, height: 32)
    }
}

private struct VolumeControl: View {
    let remote: RemoteControlModel

    var body: some View {
        VStack(spacing: 3) {
            RemoteKeyButton(remote: remote, command: .volup, symbol: "plus", label: "Subir volumen")
            RemoteKeyButton(remote: remote, command: .mute, symbol: "speaker.slash.fill", label: "Silenciar")
            RemoteKeyButton(remote: remote, command: .voldown, symbol: "minus", label: "Bajar volumen")
        }
    }
}

private struct PlaybackControl: View {
    let remote: RemoteControlModel

    var body: some View {
        HStack(spacing: 5) {
            RemoteKeyButton(remote: remote, command: .previous, symbol: "backward.end.fill", label: "Capítulo anterior")
            RemoteKeyButton(remote: remote, command: .play, symbol: "playpause.fill", label: "Reproducir o pausar", emphasized: true)
            RemoteKeyButton(remote: remote, command: .next, symbol: "forward.end.fill", label: "Capítulo siguiente")
        }
    }
}

private struct PairingControl: View {
    @ObservedObject var pairing: TVPairingModel
    @Bindable var remote: RemoteControlModel
    @Binding var host: String
    @Binding var pin: String
    var pinIsFocused: FocusState<Bool>.Binding

    private var isPaired: Bool {
        pairing.paired || remote.state == .connected
    }

    private var hostHasChanges: Bool {
        host.trimmingCharacters(in: .whitespacesAndNewlines) != remote.host
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer()

                Button {
                    pin = ""
                    pairing.start()
                } label: {
                    Image(systemName: "link")
                        .frame(width: 22, height: 18)
                }
                .buttonStyle(.borderless)
                .help(isPaired ? "Reemparejar" : "Emparejar")
                .pointingHandCursor()
            }

            if showsPairingStatus {
                Text(pairing.status)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if pairing.waitingForPIN {
                HStack(spacing: 8) {
                    TextField("Código de 6 caracteres", text: $pin)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption.monospaced())
                        .focused(pinIsFocused)
                        .onSubmit(submitPIN)

                    Button("OK", action: submitPIN)
                        .disabled(pin.count != 6)
                        .pointingHandCursor()
                }
            }

            HStack(spacing: 6) {
                TextField("Dirección IP", text: $host)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption.monospaced())
                    .onSubmit {
                        if hostHasChanges { remote.saveHost(host) }
                    }

                if hostHasChanges {
                    Button {
                        remote.saveHost(host)
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.borderless)
                    .help("Actualizar IP")
                    .pointingHandCursor()
                }

                hostUpdateIndicator
            }
            .onChange(of: host) { _, _ in
                remote.resetHostUpdateState()
            }

            HStack {
                Toggle("Sonido al pulsar", isOn: $remote.soundEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)

                Spacer()

            }
        }
        .padding(12)
        .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func submitPIN() {
        guard pin.count == 6 else { return }
        pairing.submit(pin: pin)
    }

    private var showsPairingStatus: Bool {
        pairing.waitingForPIN
            || (pairing.status != "Lista para usar" && pairing.status != "Emparejamiento completo")
    }

    @ViewBuilder
    private var hostUpdateIndicator: some View {
        switch remote.hostUpdateState {
        case .idle:
            EmptyView()
        case .updating:
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)
                .help("Actualizando IP")
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .help("IP actualizada")
        case .failed(let message):
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .help(message)
        }
    }
}

private enum RemoteKeyShape {
    case rounded
    case circle
    case square
}

private enum RemoteKeyRole {
    case standard
    case destructive
}

private struct RemoteKeyButton: View {
    let remote: RemoteControlModel
    let command: TVCommand
    var symbol: String?
    let label: String
    var text: String?
    var shape: RemoteKeyShape = .rounded
    var role: RemoteKeyRole = .standard
    var emphasized = false

    @State private var isHovered = false

    var body: some View {
        Button {
            remote.send(command)
        } label: {
            Group {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: emphasized ? 13 : 11, weight: .semibold))
                } else if let text {
                    Text(text)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                }
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(RemoteKeyButtonStyle(shape: shape, isHovered: isHovered, emphasized: emphasized))
        .frame(width: shape == .rounded ? nil : 34, height: 32)
        .onHover {
            isHovered = $0
            ($0 ? NSCursor.pointingHand : NSCursor.arrow).set()
        }
        .help(label)
        .accessibilityLabel(label)
    }

    private var foregroundColor: Color {
        role == .destructive ? .red : .primary
    }
}

private extension View {
    func pointingHandCursor() -> some View {
        onHover { isHovered in
            (isHovered ? NSCursor.pointingHand : NSCursor.arrow).set()
        }
    }
}

private struct RemoteKeyButtonStyle: ButtonStyle {
    let shape: RemoteKeyShape
    let isHovered: Bool
    let emphasized: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if shape == .circle {
                    Circle().fill(backgroundColor(configuration.isPressed))
                } else {
                    RoundedRectangle(cornerRadius: shape == .square ? 8 : 11, style: .continuous)
                        .fill(backgroundColor(configuration.isPressed))
                }
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private func backgroundColor(_ isPressed: Bool) -> Color {
        if isPressed { return .accentColor.opacity(0.22) }
        if isHovered { return .primary.opacity(0.12) }
        if emphasized { return .primary.opacity(0.10) }
        return .primary.opacity(0.055)
    }
}
