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
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DeskTips"
        window.minSize = NSSize(width: 1040, height: 560)
        window.center()
        window.setFrameAutosaveName("DeskTipsMainWindow")
        Self.enforceMinimumWindowSize(window)
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

    private static func enforceMinimumWindowSize(_ window: NSWindow) {
        let frame = window.frame
        let minSize = window.minSize
        guard frame.width < minSize.width || frame.height < minSize.height else { return }

        var adjustedFrame = frame
        adjustedFrame.size.width = max(frame.width, minSize.width)
        adjustedFrame.size.height = max(frame.height, minSize.height)
        adjustedFrame.origin.y -= adjustedFrame.height - frame.height
        window.setFrame(adjustedFrame, display: false)
    }

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
