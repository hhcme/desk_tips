import AppKit
import DeskTipsCore

final class AppDelegate: NSObject, NSApplicationDelegate {

    private(set) var todoStore: TodoStore!
    private(set) var settingsStore: SettingsStore!
    private var statusBarController: StatusBarController!
    private var overlayController: OverlayWindowController!
    private var mainWindowController: MainWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Data stores
        todoStore = TodoStore()
        settingsStore = SettingsStore()

        // Overlay (floating window on desktop)
        overlayController = OverlayWindowController(store: todoStore, settingsStore: settingsStore)

        // Main window (created but not shown)
        mainWindowController = MainWindowController(
            store: todoStore,
            settingsStore: settingsStore,
            overlayController: overlayController
        )

        // Menu bar icon + popover
        statusBarController = StatusBarController(
            store: todoStore,
            settingsStore: settingsStore,
            overlayController: overlayController,
            mainWindowController: mainWindowController
        )

        // Show overlay if settings say so
        if settingsStore.settings.isVisible {
            overlayController.showWindow(nil)
        }
    }
}
