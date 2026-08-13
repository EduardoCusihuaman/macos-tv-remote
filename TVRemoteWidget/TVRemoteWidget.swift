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
            return Color(red: 0.075, green: 0.08, blue: 0.095)
        }

        return Color(red: 0.94, green: 0.94, blue: 0.92)
    }
}

private struct RemoteView: View {
    var body: some View {
        HStack(spacing: 10) {
            VStack(spacing: 7) {
                DevicePill()

                HStack(spacing: 7) {
                    ActionButton(.back, "arrow.uturn.backward", "Volver", title: "Atrás")
                    ActionButton(.home, "house.fill", "Inicio", title: "Inicio", role: .primary)
                }

                HStack(spacing: 7) {
                    ActionButton(.play, "playpause.fill", "Reproducir o pausar", title: "Play")
                    ActionButton(.power, "power", "Encender o apagar", title: "Power", role: .destructive)
                }
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

private struct DevicePill: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "tv.fill")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(renderingMode == .fullColor ? Color.accentColor : Color.primary)
                .widgetAccentable()

            Text("TCL TV")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .lineLimit(1)

            Spacer(minLength: 2)

            Circle()
                .fill(renderingMode == .fullColor ? Color.green : Color.primary)
                .frame(width: 5, height: 5)

            Text("ON")
                .font(.system(size: 7, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, minHeight: 25)
        .background(.primary.opacity(renderingMode == .fullColor ? 0.07 : 0.12), in: Capsule())
    }
}

private enum ActionRole {
    case standard
    case primary
    case destructive
}

private struct ActionButton: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    let command: WidgetTVCommand
    let icon: String
    let label: String
    let title: String
    let role: ActionRole

    init(
        _ command: WidgetTVCommand,
        _ icon: String,
        _ label: String,
        title: String,
        role: ActionRole = .standard
    ) {
        self.command = command
        self.icon = icon
        self.label = label
        self.title = title
        self.role = role
    }

    var body: some View {
        Button(intent: TVCommandIntent(command)) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))

                Text(title)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(iconColor)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(surfaceColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .widgetAccentable(role == .primary)
        .accessibilityLabel(label)
    }

    private var iconColor: Color {
        guard renderingMode == .fullColor else { return .primary }

        switch role {
        case .standard: return .primary
        case .primary: return .accentColor
        case .destructive: return .red
        }
    }

    private var surfaceColor: Color {
        guard renderingMode == .fullColor else { return .primary.opacity(0.11) }

        switch role {
        case .standard: return .primary.opacity(0.075)
        case .primary: return .accentColor.opacity(0.20)
        case .destructive: return .red.opacity(0.15)
        }
    }
}

private struct VolumeRail: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        VStack(spacing: 2) {
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
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 34, height: 32)
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var surfaceOpacity: Double {
        renderingMode == .fullColor ? 0.07 : 0.12
    }

}

private struct DirectionPad: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        ZStack {
            Circle()
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
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .frame(width: 46, height: 46)
                    .background(centerColor, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .widgetAccentable()
            .accessibilityLabel("Aceptar")
        }
        .frame(width: 116, height: 116)
        .contentShape(Circle())
    }

    private func direction(_ command: WidgetTVCommand, _ icon: String, _ label: String) -> some View {
        Button(intent: TVCommandIntent(command)) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var surfaceOpacity: Double {
        renderingMode == .fullColor ? 0.06 : 0.10
    }

    private var centerColor: Color {
        renderingMode == .fullColor ? .accentColor.opacity(0.16) : .primary.opacity(0.18)
    }

}
