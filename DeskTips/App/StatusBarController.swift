import AppKit
import SwiftUI
import DeskTipsCore

/// Manages the menu bar status item and its popover.
@MainActor
final class StatusBarController {

    private let statusItem: NSStatusItem
    private let popover: NSPopover
    nonisolated(unsafe) private var eventMonitor: Any?

    private let store: TodoStore
    private let settingsStore: SettingsStore
    private let overlayController: OverlayWindowController
    private weak var mainWindowController: MainWindowController?

    init(
        store: TodoStore,
        settingsStore: SettingsStore,
        overlayController: OverlayWindowController,
        mainWindowController: MainWindowController? = nil
    ) {
        self.store = store
        self.settingsStore = settingsStore
        self.overlayController = overlayController
        self.mainWindowController = mainWindowController

        // Status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // Popover with SwiftUI settings view
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 440)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: SettingsView(
                store: store,
                settingsStore: settingsStore,
                overlayController: overlayController,
                onOpenMainWindow: { [weak mainWindowController] in
                    mainWindowController?.showMainWindow()
                }
            )
        )

        // Now safe to use self
        if let button = statusItem.button {
            button.image = Self.makeStatusBarImage()
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Close popover on click outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            guard let button = statusItem.button else { return }
            // Activate app BEFORE showing popover — required for keyboard shortcuts
            // (paste, copy, etc.) to work in LSUIElement menu bar apps
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Ensure the popover's window becomes key for text input
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func closePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }

    private static func makeStatusBarImage() -> NSImage? {
        let image = NSImage(named: "MenuBarIcon")
            ?? NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "DeskTips")

        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        image?.accessibilityDescription = "DeskTips"
        return image
    }
}
