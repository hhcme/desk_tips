import Testing
import Foundation
@testable import DeskTipsCore

/// In-memory settings persistence for testing.
final class MockSettingsPersistence: SettingsPersistence, @unchecked Sendable {
    var stored = OverlaySettings()
    private(set) var saveCount = 0

    func load() -> OverlaySettings { stored }

    func save(_ settings: OverlaySettings) {
        stored = settings
        saveCount += 1
    }
}

@MainActor
@Suite("SettingsStore tests")
struct SettingsStoreTests {

    @Test("Init loads from persistence")
    func initLoads() {
        let mock = MockSettingsPersistence()
        mock.stored = OverlaySettings(displayMode: .transparent, glassIntensity: 0.5, transparentOpacity: 0.9, isVisible: false)
        let store = SettingsStore(persistence: mock)
        #expect(store.settings.displayMode == .transparent)
        #expect(store.settings.glassIntensity == 0.5)
        #expect(store.settings.isVisible == false)
    }

    @Test("Update display mode saves")
    func updateDisplayMode() {
        let mock = MockSettingsPersistence()
        let store = SettingsStore(persistence: mock)
        store.updateDisplayMode(.transparent)
        #expect(store.settings.displayMode == .transparent)
        #expect(mock.saveCount == 1)
    }

    @Test("Update glass intensity clamps and saves")
    func updateGlassIntensity() {
        let mock = MockSettingsPersistence()
        let store = SettingsStore(persistence: mock)
        store.updateGlassIntensity(0.42)
        #expect(store.settings.glassIntensity == 0.42)
        // Test clamping
        store.updateGlassIntensity(1.5)
        #expect(store.settings.glassIntensity == 1.0)
        store.updateGlassIntensity(-0.1)
        #expect(store.settings.glassIntensity == 0.0)
    }

    @Test("Update transparent opacity clamps and saves")
    func updateTransparentOpacity() {
        let mock = MockSettingsPersistence()
        let store = SettingsStore(persistence: mock)
        store.updateTransparentOpacity(0.6)
        #expect(store.settings.transparentOpacity == 0.6)
        // Test clamping (min 0.3)
        store.updateTransparentOpacity(0.1)
        #expect(store.settings.transparentOpacity == 0.3)
        store.updateTransparentOpacity(1.5)
        #expect(store.settings.transparentOpacity == 1.0)
    }

    @Test("Toggle visibility")
    func toggleVisibility() {
        let mock = MockSettingsPersistence()
        let store = SettingsStore(persistence: mock)
        #expect(store.settings.isVisible == true)
        store.toggleVisibility()
        #expect(store.settings.isVisible == false)
        store.toggleVisibility()
        #expect(store.settings.isVisible == true)
    }

    @Test("Set visible")
    func setVisible() {
        let mock = MockSettingsPersistence()
        let store = SettingsStore(persistence: mock)
        store.setVisible(false)
        #expect(store.settings.isVisible == false)
        #expect(mock.saveCount == 1)
    }

    @Test("Persistence round-trip")
    func persistenceRoundTrip() {
        let mock = MockSettingsPersistence()
        let store = SettingsStore(persistence: mock)
        store.updateDisplayMode(.transparent)
        store.updateTransparentOpacity(0.55)
        // Create new store from same persistence
        let store2 = SettingsStore(persistence: mock)
        #expect(store2.settings.displayMode == .transparent)
        #expect(store2.settings.transparentOpacity == 0.55)
    }
}
