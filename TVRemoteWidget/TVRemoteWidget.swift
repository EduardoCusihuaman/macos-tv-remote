import WidgetKit
import SwiftUI

struct TVEntry: TimelineEntry {
    let date: Date
}

struct TVProvider: TimelineProvider {
    func placeholder(in context: Context) -> TVEntry { .init(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (TVEntry) -> Void) {
        completion(.init(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TVEntry>) -> Void) {
        completion(.init(entries: [.init(date: .now)], policy: .never))
    }
}

struct TVRemoteWidget: Widget {
    var body: some WidgetConfiguration {
        tvRemoteConfiguration(kind: "TVRemoteWidget.v2", name: "TV Remote")
    }
}

struct TVRemoteWidgetLegacy: Widget {
    var body: some WidgetConfiguration {
        tvRemoteConfiguration(kind: "TVRemoteWidget", name: "TV Remote (Anterior)")
    }
}

private func tvRemoteConfiguration(kind: String, name: LocalizedStringKey) -> some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: TVProvider()) { _ in
        RemoteView()
            .containerBackground(for: .widget) {
                AdaptiveWidgetBackground()
            }
    }
    .configurationDisplayName(name)
    .description("Control directo para Google TV.")
    .supportedFamilies([.systemMedium])
    .containerBackgroundRemovable(false)
}

private struct AdaptiveWidgetBackground: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        backgroundColor
    }

    private var backgroundColor: Color {
        guard renderingMode == .fullColor else {
            return Color(red: 0.09, green: 0.10, blue: 0.12)
        }

        if colorScheme == .dark {
            return Color(red: 0.055, green: 0.06, blue: 0.075)
        }

        return Color(red: 0.925, green: 0.93, blue: 0.945)
    }
}

private struct RemoteView: View {
    var body: some View {
        HStack(spacing: 9) {
            VStack(spacing: 7) {
                DeviceStatus()

                HStack(spacing: 6) {
                    IconButton(.power, "power", "Encender o apagar", role: .destructive)
                    IconButton(.home, "house.fill", "Inicio")
                    IconButton(.back, "chevron.backward", "Volver")
                }

                PlaybackControls()
            }
            .frame(maxWidth: .infinity)

            VolumeRail()
                .frame(width: 42, height: 116)

            DirectionPad()
                .frame(width: 116, height: 116)
        }
        .foregroundStyle(.primary)
    }
}

private struct DeviceStatus: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "tv.fill")
                .font(.system(size: 11, weight: .semibold))
                .widgetAccentable()

            Text("TCL TV")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)

            Spacer(minLength: 2)

            Circle()
                .fill(renderingMode == .fullColor ? Color.green : Color.primary)
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, minHeight: 24)
    }
}

private enum ActionRole {
    case standard
    case destructive
}

private struct IconButton: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    let command: WidgetTVCommand
    let icon: String
    let label: String
    let role: ActionRole

    init(
        _ command: WidgetTVCommand,
        _ icon: String,
        _ label: String,
        role: ActionRole = .standard
    ) {
        self.command = command
        self.icon = icon
        self.label = label
        self.role = role
    }

    var body: some View {
        Button(intent: TVCommandIntent(command)) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconColor)
            .frame(maxWidth: .infinity)
            .frame(height: 35)
            .background(.primary.opacity(surfaceOpacity), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var iconColor: Color {
        guard renderingMode == .fullColor else { return .primary }

        switch role {
        case .standard: return .primary
        case .destructive: return .red
        }
    }

    private var surfaceOpacity: Double {
        renderingMode == .fullColor ? 0.075 : 0.12
    }
}

private struct PlaybackControls: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        HStack(spacing: 0) {
            mediaButton(.previous, "backward.end.fill", "Capítulo anterior")
            mediaButton(.play, "playpause.fill", "Reproducir o pausar", emphasized: true)
            mediaButton(.next, "forward.end.fill", "Capítulo siguiente")
        }
        .frame(height: 43)
        .background(.primary.opacity(surfaceOpacity), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func mediaButton(
        _ command: WidgetTVCommand,
        _ icon: String,
        _ label: String,
        emphasized: Bool = false
    ) -> some View {
        Button(intent: TVCommandIntent(command)) {
            Image(systemName: icon)
                .font(.system(size: emphasized ? 14 : 11, weight: .semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var surfaceOpacity: Double {
        renderingMode == .fullColor ? 0.075 : 0.12
    }
}

private struct VolumeRail: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        VStack(spacing: 1) {
            segment(.volup, "plus", "Subir volumen")
            segment(.mute, "speaker.slash.fill", "Silenciar")
            segment(.voldown, "minus", "Bajar volumen")
        }
        .padding(.vertical, 4)
        .frame(width: 42, height: 116)
        .background(.primary.opacity(surfaceOpacity), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func segment(_ command: WidgetTVCommand, _ icon: String, _ label: String) -> some View {
        Button(intent: TVCommandIntent(command)) {
            Image(systemName: icon)
                .font(.system(size: command == .mute ? 9 : 11, weight: .bold))
                .frame(width: 34, height: 32)
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var surfaceOpacity: Double {
        renderingMode == .fullColor ? 0.085 : 0.12
    }

}

private struct DirectionPad: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        ZStack {
            DirectionPadShape()
                .fill(.primary.opacity(surfaceOpacity))

            direction(.up, "chevron.up", "Arriba")
                .offset(y: -39)
            direction(.down, "chevron.down", "Abajo")
                .offset(y: 39)
            direction(.left, "chevron.left", "Izquierda")
                .offset(x: -39)
            direction(.right, "chevron.right", "Derecha")
                .offset(x: 39)

            Button(intent: TVCommandIntent(.ok)) {
                Text("OK")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .frame(width: 44, height: 44)
                    .background(centerColor, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .widgetAccentable()
            .accessibilityLabel("Aceptar")
        }
        .frame(width: 116, height: 116)
        .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private func direction(_ command: WidgetTVCommand, _ icon: String, _ label: String) -> some View {
        Button(intent: TVCommandIntent(command)) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 38, height: 38)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var surfaceOpacity: Double {
        renderingMode == .fullColor ? 0.085 : 0.12
    }

    private var centerColor: Color {
        .primary.opacity(renderingMode == .fullColor ? 0.13 : 0.18)
    }

}

private struct DirectionPadShape: Shape {
    func path(in rect: CGRect) -> Path {
        let thickness: CGFloat = 44
        let radius = thickness / 2
        var path = Path()

        path.addRoundedRect(
            in: CGRect(
                x: rect.midX - thickness / 2,
                y: rect.minY,
                width: thickness,
                height: rect.height
            ),
            cornerSize: CGSize(width: radius, height: radius)
        )
        path.addRoundedRect(
            in: CGRect(
                x: rect.minX,
                y: rect.midY - thickness / 2,
                width: rect.width,
                height: thickness
            ),
            cornerSize: CGSize(width: radius, height: radius)
        )
        return path
    }
}
