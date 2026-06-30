import Foundation

/// Abstraction for overlay settings persistence.
public protocol SettingsPersistence {
    func load() -> OverlaySettings
    func save(_ settings: OverlaySettings)
}

/// UserDefaults-backed settings persistence using JSON encoding.
public struct UserDefaultsSettingsPersistence: SettingsPersistence, @unchecked Sendable {
    private let key = "com.desktips.overlaySettings"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> OverlaySettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(OverlaySettings.self, from: data)
        else {
            return OverlaySettings()
        }
        return settings
    }

    public func save(_ settings: OverlaySettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
