import Foundation

enum TVConfig {
    static let name = "TCL TV"
    private static let defaultHost = "192.168.100.135"
    private static let hostKey = "tvHost"
    private static let soundKey = "controlSoundEnabled"

    static var host: String {
        get { UserDefaults.standard.string(forKey: hostKey) ?? defaultHost }
        set { UserDefaults.standard.set(newValue, forKey: hostKey) }
    }

    static var soundEnabled: Bool {
        get {
            guard UserDefaults.standard.object(forKey: soundKey) != nil else { return true }
            return UserDefaults.standard.bool(forKey: soundKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: soundKey) }
    }
}
