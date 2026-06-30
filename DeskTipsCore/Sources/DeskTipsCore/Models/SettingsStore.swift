import Foundation
import SwiftUI

/// Observable store for overlay display settings. Auto-saves on every mutation.
@MainActor
public final class SettingsStore: ObservableObject {
    @Published public private(set) var settings: OverlaySettings

    private let persistence: SettingsPersistence

    public init(persistence: SettingsPersistence = UserDefaultsSettingsPersistence()) {
        self.persistence = persistence
        self.settings = persistence.load()
    }

    public func updateDisplayMode(_ mode: OverlayDisplayMode) {
        settings.displayMode = mode
        save()
    }

    public func updateGlassIntensity(_ value: Double) {
        settings.glassIntensity = min(max(value, 0), 1)
        save()
    }

    public func updateTransparentOpacity(_ value: Double) {
        settings.transparentOpacity = min(max(value, 0.3), 1)
        save()
    }

    public func toggleVisibility() {
        settings.isVisible.toggle()
        save()
    }

    public func setVisible(_ visible: Bool) {
        settings.isVisible = visible
        save()
    }

    public func updateOverlayTitle(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        settings.overlayTitle = trimmed
        save()
    }

    private func save() {
        persistence.save(settings)
    }
}
