import AppIntents

enum WidgetTVCommand: String, AppEnum {
    case up, down, left, right, ok, back, home, power
    case volup, voldown, mute, play, previous, next

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "TV command")

    static var caseDisplayRepresentations: [WidgetTVCommand: DisplayRepresentation] = [
        .up: "Up", .down: "Down", .left: "Left", .right: "Right",
        .ok: "OK", .back: "Back", .home: "Home", .power: "Power",
        .volup: "Volume up", .voldown: "Volume down",
        .mute: "Mute", .play: "Play/Pause",
        .previous: "Previous chapter", .next: "Next chapter"
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
        let id = String(UUID().uuidString.prefix(8))
        let pid = ProcessInfo.processInfo.processIdentifier
        let clock = ContinuousClock()
        let start = clock.now

        TVRemoteLog.remote.notice(
            "intent.begin id=\(id, privacy: .public) pid=\(pid) cmd=\(command.rawValue, privacy: .public)"
        )

        do {
            try await TVOneShotSender().send(command.command, id: id)
            let elapsed = String(describing: start.duration(to: clock.now))
            TVRemoteLog.remote.notice(
                "intent.end id=\(id, privacy: .public) duration=\(elapsed, privacy: .public)"
            )
        } catch {
            TVRemoteLog.remote.error(
                "intent.error id=\(id, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
        }
        return .result()
    }
}
