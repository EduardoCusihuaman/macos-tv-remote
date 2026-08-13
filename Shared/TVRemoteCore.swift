import Foundation
import Security
import AndroidTVRemoteControl

enum TVRemoteCoreError: LocalizedError {
    case missingCertificate
    case connectionTimedOut

    var errorDescription: String? {
        switch self {
        case .missingCertificate:
            return "No encontré cert.der/cert.p12 dentro de la app."
        case .connectionTimedOut:
            return "La TV no respondió a tiempo."
        }
    }
}

enum TVResources {
    private static let certificatePassword = "tvremote"

    static func certificateURL(_ ext: String) -> URL? {
        Bundle.main.url(forResource: "cert", withExtension: ext)
    }

    static func tlsManager(cryptoManager: CryptoManager? = nil) throws -> TLSManager {
        guard let p12 = certificateURL("p12") else {
            throw TVRemoteCoreError.missingCertificate
        }

        let tls = TLSManager {
            CertManager().cert(p12, certificatePassword)
        }

        if let cryptoManager {
            tls.secTrustClosure = { trust in
                cryptoManager.serverPublicCertificate = {
                    guard let key = SecTrustCopyKey(trust) else {
                        return .Error(.secTrustCopyKeyError)
                    }
                    return .Result(key)
                }
            }
        }

        return tls
    }

    static func cryptoManager() throws -> CryptoManager {
        guard let der = certificateURL("der") else {
            throw TVRemoteCoreError.missingCertificate
        }

        let crypto = CryptoManager()
        crypto.clientPublicCertificate = {
            CertManager().getSecKey(der)
        }
        return crypto
    }
}

enum TVCommand: String, CaseIterable {
    case up, down, left, right, ok, back, home, power
    case volup, voldown, mute, play, previous, next

    var key: Key {
        switch self {
        case .up:      return .KEYCODE_DPAD_UP
        case .down:    return .KEYCODE_DPAD_DOWN
        case .left:    return .KEYCODE_DPAD_LEFT
        case .right:   return .KEYCODE_DPAD_RIGHT
        case .ok:      return .KEYCODE_DPAD_CENTER
        case .back:    return .KEYCODE_BACK
        case .home:    return .KEYCODE_HOME
        case .power:   return .KEYCODE_POWER
        case .volup:   return .KEYCODE_VOLUME_UP
        case .voldown: return .KEYCODE_VOLUME_DOWN
        case .mute:    return .KEYCODE_VOLUME_MUTE
        case .play:    return .KEYCODE_MEDIA_PLAY_PAUSE
        case .previous: return .KEYCODE_MEDIA_PREVIOUS
        case .next:     return .KEYCODE_MEDIA_NEXT
        }
    }
}

/// Keeps TLS warm briefly so consecutive remote presses avoid reconnecting.
final class TVOneShotSender {
    func send(_ command: TVCommand) async throws {
        try await TVRemoteSession.shared.send(command)
    }
}

private actor TVRemoteSession {
    static let shared = TVRemoteSession()

    private struct PendingCommand {
        let command: TVCommand
        let continuation: CheckedContinuation<Void, Error>
    }

    private var remote: RemoteManager?
    private var pending: [PendingCommand] = []
    private var isConnecting = false
    private var isPaired = false
    private var connectionGeneration = 0
    private var idleTask: Task<Void, Never>?

    func send(_ command: TVCommand) async throws {
        if isPaired, let remote {
            remote.send(KeyPress(command.key))
            scheduleIdleDisconnect(generation: connectionGeneration)
            return
        }

        try await withCheckedThrowingContinuation { continuation in
            pending.append(.init(command: command, continuation: continuation))
            guard !isConnecting else { return }

            do {
                let manager = try makeRemoteManager()
                remote = manager
                isConnecting = true
                connectionGeneration += 1
                let generation = connectionGeneration

                manager.stateChanged = { [weak self] state in
                    Task { await self?.handle(state, generation: generation) }
                }
                manager.connect(TVConfig.host, timeout: 3)

                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(4))
                    await self?.connectionTimedOut(generation: generation)
                }
            } catch {
                failPending(with: error)
            }
        }
    }

    private func makeRemoteManager() throws -> RemoteManager {
        RemoteManager(
            try TVResources.tlsManager(),
            CommandNetwork.DeviceInfo(
                "Mac TV Widget",
                "Mac",
                "1.0",
                "TVRemote",
                "1"
            )
        )
    }

    private func handle(_ state: RemoteManager.RemoteState, generation: Int) async {
        guard generation == connectionGeneration else { return }

        switch state {
        case .paired:
            isConnecting = false
            isPaired = true

            let commands = pending
            pending.removeAll()
            for item in commands {
                remote?.send(KeyPress(item.command.key))
            }

            commands.forEach { $0.continuation.resume() }
            scheduleIdleDisconnect(generation: generation)

        case .error(let error):
            closeConnection()
            failPending(with: error)

        default:
            break
        }
    }

    private func connectionTimedOut(generation: Int) {
        guard generation == connectionGeneration, isConnecting else { return }
        closeConnection()
        failPending(with: TVRemoteCoreError.connectionTimedOut)
    }

    private func scheduleIdleDisconnect(generation: Int) {
        idleTask?.cancel()
        idleTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await self?.disconnectIfIdle(generation: generation)
        }
    }

    private func disconnectIfIdle(generation: Int) {
        guard generation == connectionGeneration else { return }
        closeConnection()
    }

    private func closeConnection() {
        idleTask?.cancel()
        idleTask = nil
        remote?.stateChanged = nil
        remote?.disconnect()
        remote = nil
        isConnecting = false
        isPaired = false
    }

    private func failPending(with error: Error) {
        let commands = pending
        pending.removeAll()
        commands.forEach { $0.continuation.resume(throwing: error) }
    }
}

/// Pairing nativo para cuando quieras reautorizar el certificado.
@MainActor
final class TVPairingModel: ObservableObject {
    @Published var status = "Lista para usar"
    @Published var waitingForPIN = false
    @Published var paired = false

    private var pairing: PairingManager?

    func start() {
        do {
            status = "Conectando..."
            waitingForPIN = false
            paired = false

            let crypto = try TVResources.cryptoManager()
            let tls = try TVResources.tlsManager(cryptoManager: crypto)
            let manager = PairingManager(tls, crypto)

            manager.stateChanged = { [weak self] state in
                DispatchQueue.main.async {
                    guard let self else { return }

                    switch state {
                    case .waitingCode:
                        self.status = "Ingresá el código que aparece en la TV"
                        self.waitingForPIN = true

                    case .successPaired:
                        self.status = "Emparejamiento completo"
                        self.waitingForPIN = false
                        self.paired = true
                        manager.disconnect()

                    case .error(let error):
                        self.status = "Error: \(error.localizedDescription)"
                        self.waitingForPIN = false

                    default:
                        break
                    }
                }
            }

            pairing = manager
            manager.connect(TVConfig.host, "Mac TV Widget", "Mac")

        } catch {
            status = "Error: \(error.localizedDescription)"
        }
    }

    func submit(pin: String) {
        pairing?.sendSecret(pin.uppercased())
        status = "Verificando..."
    }
}
