import AppKit
import Combine
import SwiftUI
import DeskTipsCore

/// Manages the menu bar status item and its popover.
@MainActor
final class StatusBarController {

    private let statusItem: NSStatusItem
    private let popover: NSPopover
    nonisolated(unsafe) private var eventMonitor: Any?
    private var updateObserver: AnyCancellable?

    private let store: TodoStore
    private let settingsStore: SettingsStore
    private let overlayController: OverlayWindowController
    private weak var mainWindowController: MainWindowController?
    private let updateManager = UpdateManager.shared

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
        popover.contentSize = NSSize(width: 320, height: 250)
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
            button.image = Self.makeStatusBarImage(hasUpdate: updateManager.hasAvailableUpdate)
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.action = #selector(togglePopover)
            button.target = self
        }

        updateObserver = updateManager.$hasAvailableUpdate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasAvailableUpdate in
                self?.updateStatusBarImage(hasUpdate: hasAvailableUpdate)
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

    private func updateStatusBarImage(hasUpdate: Bool) {
        statusItem.button?.image = Self.makeStatusBarImage(hasUpdate: hasUpdate)
    }

    private static func makeStatusBarImage(hasUpdate: Bool) -> NSImage? {
        let image = NSImage(named: "MenuBarIcon")
            ?? NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "DeskTips")

        guard hasUpdate, let image else {
            image?.isTemplate = true
            image?.size = NSSize(width: 18, height: 18)
            image?.accessibilityDescription = "DeskTips"
            return image
        }

        return makeBadgedImage(from: image)
    }

    private static func makeBadgedImage(from baseImage: NSImage) -> NSImage {
        let canvasSize = NSSize(width: 20, height: 18)
        let imageRect = NSRect(x: 1, y: 0, width: 18, height: 18)
        let badgeRect = NSRect(x: 15.2, y: 12.4, width: 4.8, height: 4.8)

        let badgedImage = NSImage(size: canvasSize)
        badgedImage.lockFocus()

        if let cgImage = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
           let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            context.clip(to: imageRect, mask: cgImage)
            NSColor.labelColor.setFill()
            imageRect.fill()
            context.restoreGState()
        } else {
            baseImage.draw(in: imageRect)
        }

        NSColor.systemRed.withAlphaComponent(0.96).setFill()
        NSBezierPath(ovalIn: badgeRect).fill()

        badgedImage.unlockFocus()
        badgedImage.isTemplate = false
        badgedImage.accessibilityDescription = "DeskTips，有新版本"
        return badgedImage
    }
}
