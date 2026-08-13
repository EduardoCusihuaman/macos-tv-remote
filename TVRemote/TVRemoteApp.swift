import SwiftUI

@main
struct TVRemoteApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @StateObject private var pairing = TVPairingModel()
    @State private var pin = ""
    @State private var testStatus = ""
    @State private var isTesting = false
    @FocusState private var pinIsFocused: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.14), .clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                header
                connectionCard
                widgetHint
            }
            .padding(24)
        }
        .frame(width: 440)
        .onChange(of: pairing.waitingForPIN) { _, waiting in
            pinIsFocused = waiting
        }
        .onChange(of: pin) { _, value in
            let normalized = String(value.uppercased().prefix(6))
            if pin != normalized {
                pin = normalized
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "tv.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 2) {
                Text("TV Remote")
                    .font(.title2.bold())
                Text("TCL · \(TVConfig.host)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label(
                pairing.paired ? "Lista" : "Local",
                systemImage: pairing.paired ? "checkmark.circle.fill" : "wifi"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(pairing.paired ? .green : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quaternary, in: Capsule())
        }
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: connectionIcon)
                    .font(.title3)
                    .foregroundStyle(connectionColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(pairing.paired ? "TV conectada" : "Conexión")
                        .font(.headline)
                    Text(pairing.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }

            if pairing.waitingForPIN {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Código de la TV")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        TextField("PIN de 6 caracteres", text: $pin)
                            .textFieldStyle(.roundedBorder)
                            .font(.body.monospaced())
                            .focused($pinIsFocused)
                            .onSubmit(submitPIN)

                        Button("Confirmar", action: submitPIN)
                            .buttonStyle(.borderedProminent)
                            .disabled(pin.count != 6)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack(spacing: 10) {
                Button(action: testHome) {
                    Label(isTesting ? "Probando..." : "Probar control", systemImage: "house.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTesting)

                Button {
                    pin = ""
                    pairing.start()
                } label: {
                    Label(pairing.paired ? "Reemparejar" : "Emparejar", systemImage: "link")
                }
                .buttonStyle(.bordered)
            }

            if !testStatus.isEmpty {
                Label(
                    testStatus,
                    systemImage: testStatus == "Control funcionando"
                        ? "checkmark.circle.fill"
                        : "exclamationmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(testStatus == "Control funcionando" ? .green : .red)
                .transition(.opacity)
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .animation(.snappy, value: pairing.waitingForPIN)
    }

    private var widgetHint: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.3.group.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Controlá desde el widget")
                    .font(.callout.weight(.semibold))
                Text("Centro de notificaciones → Editar widgets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var connectionIcon: String {
        if pairing.paired { return "checkmark.circle.fill" }
        if pairing.status.hasPrefix("Error:") { return "exclamationmark.triangle.fill" }
        return "dot.radiowaves.left.and.right"
    }

    private var connectionColor: Color {
        if pairing.paired { return .green }
        if pairing.status.hasPrefix("Error:") { return .red }
        return .accentColor
    }

    private func testHome() {
        isTesting = true
        testStatus = ""

        Task {
            do {
                try await TVOneShotSender().send(.home)
                testStatus = "Control funcionando"
            } catch {
                testStatus = error.localizedDescription
            }
            isTesting = false
        }
    }

    private func submitPIN() {
        guard pin.count == 6 else { return }
        pairing.submit(pin: pin)
    }
}
