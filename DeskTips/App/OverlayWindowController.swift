import AppKit
import SwiftUI
import Combine
import DeskTipsCore

/// Manages the floating transparent overlay window.
@MainActor
final class OverlayWindowController: NSWindowController {

    private let store: TodoStore
    private let settingsStore: SettingsStore
    private var hostingController: NSHostingController<OverlayContentView>!
    private var cancellables = Set<AnyCancellable>()
    nonisolated(unsafe) private var keyEventMonitor: Any?

    init(store: TodoStore, settingsStore: SettingsStore) {
        self.store = store
        self.settingsStore = settingsStore

        let window = OverlayPanel(
            contentRect: NSRect(x: 200, y: 200, width: 280, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.hidesOnDeactivate = false
        window.isRestorable = false
        window.acceptsMouseMovedEvents = true
        window.setFrameAutosaveName("DeskTipsOverlay")
        window.identifier = NSUserInterfaceItemIdentifier("DeskTipsOverlay")

        super.init(window: window)

        let contentView = OverlayContentView(
            store: store,
            settingsStore: settingsStore,
            onEditModeChanged: { [weak self] editMode in
                self?.applyEditMode(editMode)
            }
        )
        hostingController = NSHostingController(rootView: contentView)
        hostingController.view.wantsLayer = true

        window.contentViewController = hostingController
        hostingController.view.layoutSubtreeIfNeeded()
        let fittingSize = hostingController.view.fittingSize
        window.setContentSize(NSSize(width: max(fittingSize.width, 280), height: max(fittingSize.height, 200)))

        if !window.frameAutosaveName.isEmpty,
           UserDefaults.standard.string(forKey: "NSWindow Frame DeskTipsOverlay") == nil {
            if let screen = NSScreen.main {
                let sf = screen.visibleFrame
                window.setFrameOrigin(NSPoint(x: sf.maxX - 300, y: sf.maxY - 460))
            }
        }

        settingsStore.$settings
            .map(\.isVisible)
            .removeDuplicates()
            .sink { [weak self] isVisible in
                guard let self, let win = self.window else { return }
                if isVisible { win.orderFront(nil) } else { win.orderOut(nil) }
            }
            .store(in: &cancellables)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    deinit {
        if let monitor = keyEventMonitor { NSEvent.removeMonitor(monitor) }
    }

    // MARK: - Edit Mode

    private func applyEditMode(_ editMode: Bool) {
        guard let win = window else { return }
        let topY = win.frame.maxY

        if editMode {
            win.isMovableByWindowBackground = false
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            win.makeKeyAndOrderFront(nil)

            // Start intercepting keyboard events for paste/copy/etc.
            startKeyEventMonitor()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                win.makeFirstResponder(win.contentView)
            }
        } else {
            win.isMovableByWindowBackground = true
            win.resignKey()
            NSApp.setActivationPolicy(.accessory)
            stopKeyEventMonitor()
        }

        // Resize keeping top edge fixed
        DispatchQueue.main.async { [weak self] in
            guard let self, let hosting = self.hostingController else { return }
            hosting.view.layoutSubtreeIfNeeded()
            let s = hosting.view.fittingSize
            win.setContentSize(NSSize(width: max(s.width, 280), height: max(s.height, 200)))
            win.setFrameOrigin(CGPoint(x: win.frame.origin.x, y: topY - max(s.height, 200)))
        }
    }

    // MARK: - Keyboard Event Monitor

    /// Intercepts keyboard events (Cmd+V, Cmd+C, etc.) and forwards them
    /// to the window's first responder, bypassing system-level interception.
    private func startKeyEventMonitor() {
        guard keyEventMonitor == nil else { return }
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            guard let self, let win = self.window, win.isKeyWindow else { return event }

            // Let Cmd+key shortcuts (paste, copy, etc.) go through the normal
            // menu routing system — do NOT intercept them here.
            if event.modifierFlags.contains(.command) {
                return event  // pass to AppKit's sendEvent → performKeyEquivalent → menu
            }

            // Forward plain key events to the first responder
            if let responder = win.firstResponder {
                switch event.type {
                case .keyDown: responder.keyDown(with: event)
                case .keyUp: responder.keyUp(with: event)
                case .flagsChanged: responder.flagsChanged(with: event)
                default: break
                }
                return nil
            }
            return event
        }
    }

    private func stopKeyEventMonitor() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }

    // MARK: - Public API

    func toggleOverlay() { settingsStore.toggleVisibility() }
    var isOverlayVisible: Bool { settingsStore.settings.isVisible }
}

/// Custom NSPanel that can become key and forwards keyboard shortcuts to first responder.
private class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // Let the Edit menu's Cmd+C/V/X/A/Z reach the first responder (TextField)
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isKeyWindow, let responder = firstResponder {
            return responder.performKeyEquivalent(with: event)
        }
        return super.performKeyEquivalent(with: event)
    }
}
