import AppIntents

enum WidgetTVCommand: String, AppEnum {
    case up, down, left, right, ok, back, home, power
    case volup, voldown, mute, play

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "TV command")

    static var caseDisplayRepresentations: [WidgetTVCommand: DisplayRepresentation] = [
        .up: "Up", .down: "Down", .left: "Left", .right: "Right",
        .ok: "OK", .back: "Back", .home: "Home", .power: "Power",
        .volup: "Volume up", .voldown: "Volume down",
        .mute: "Mute", .play: "Play/Pause"
    ]

    var command: TVCommand { TVCommand(rawValue: rawValue)! }
}

struct TVCommandIntent: AppIntent {
    static var title: LocalizedStringResource = "Control TV"
    static var openAppWhenRun = false

    @Parameter(title: "Command")
    var command: WidgetTVCommand

    init() {}

    init(_ command: WidgetTVCommand) {
        self.command = command
    }

    func perform() async throws -> some IntentResult {
        do {
            try await TVOneShotSender().send(command.command)
        } catch {
            // Widget interactions can't present errors; keep the control responsive.
        }
        return .result()
    }
}
