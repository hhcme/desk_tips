import AppKit
import DeskTipsCore

final class AppDelegate: NSObject, NSApplicationDelegate {

    private(set) var todoStore: TodoStore!
    private(set) var settingsStore: SettingsStore!
    private var statusBarController: StatusBarController!
    private var overlayController: OverlayWindowController!
    private var mainWindowController: MainWindowController!
    private var updateManager: UpdateManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        todoStore = TodoStore()
        settingsStore = SettingsStore()
        updateManager = UpdateManager.shared

        // Request notification permission and check overdue
        Task {
            _ = await NotificationManager.shared.requestPermission()
            NotificationManager.shared.checkOverdueItems(store: todoStore)
            NotificationManager.shared.rescheduleAll(
                store: todoStore,
                reminderOffset: settingsStore.settings.defaultReminderOffset
            )
        }

        overlayController = OverlayWindowController(store: todoStore, settingsStore: settingsStore)

        mainWindowController = MainWindowController(
            store: todoStore,
            settingsStore: settingsStore,
            overlayController: overlayController
        )

        statusBarController = StatusBarController(
            store: todoStore,
            settingsStore: settingsStore,
            overlayController: overlayController,
            mainWindowController: mainWindowController
        )

        updateManager.performLaunchCheckIfNeeded()

        if settingsStore.settings.isVisible {
            overlayController.showWindow(nil)
        }
    }
}
