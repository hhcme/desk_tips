import AppKit
import SwiftUI
import DeskTipsCore

/// Main application window with tabbed interface.
@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate {

    private let store: TodoStore
    private let settingsStore: SettingsStore
    private let overlayController: OverlayWindowController

    init(store: TodoStore, settingsStore: SettingsStore, overlayController: OverlayWindowController) {
        self.store = store
        self.settingsStore = settingsStore
        self.overlayController = overlayController

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DeskTips"
        window.center()
        window.setFrameAutosaveName("DeskTipsMainWindow")
        window.minSize = NSSize(width: 420, height: 400)
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self

        let contentView = MainTabView(
            store: store,
            settingsStore: settingsStore,
            overlayController: overlayController
        )
        window.contentViewController = NSHostingController(rootView: contentView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func showMainWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // Show in dock while main window is open
        NSApp.setActivationPolicy(.regular)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // Hide dock icon when main window closes
        NSApp.setActivationPolicy(.accessory)
    }
}
