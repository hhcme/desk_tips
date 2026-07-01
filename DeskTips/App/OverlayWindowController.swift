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
    private let restoreMargin: CGFloat = 12

    init(store: TodoStore, settingsStore: SettingsStore) {
        self.store = store
        self.settingsStore = settingsStore

        let window = OverlayPanel(
            contentRect: NSRect(x: 200, y: 200, width: 280, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
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
        window.becomesKeyOnlyIfNeeded = true
        window.identifier = NSUserInterfaceItemIdentifier("DeskTipsOverlay")

        super.init(window: window)

        let contentView = OverlayContentView(store: store, settingsStore: settingsStore)
        hostingController = NSHostingController(rootView: contentView)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor

        window.contentViewController = hostingController
        hostingController.view.layoutSubtreeIfNeeded()
        let fittingSize = hostingController.view.fittingSize
        window.setContentSize(NSSize(width: max(fittingSize.width, 280), height: max(fittingSize.height, 200)))

        applyInitialFrame(to: window)
        window.delegate = self
        persistWindowPlacement(for: window)

        settingsStore.$settings
            .map(\.isVisible)
            .removeDuplicates()
            .sink { [weak self] isVisible in
                guard let self, let win = self.window else { return }
                if isVisible { win.orderFrontRegardless() } else { win.orderOut(nil) }
            }
            .store(in: &cancellables)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Public API

    func toggleOverlay() { settingsStore.toggleVisibility() }
    var isOverlayVisible: Bool { settingsStore.settings.isVisible }

    // MARK: - Placement

    private func applyInitialFrame(to window: NSWindow) {
        let windowSize = window.frame.size
        let origin: NSPoint

        if let placement = settingsStore.settings.overlayWindowPlacement {
            origin = restoredOrigin(for: placement, windowSize: windowSize)
        } else {
            origin = defaultOrigin(for: windowSize)
        }

        window.setFrameOrigin(origin)
    }

    private func restoredOrigin(for placement: OverlayWindowPlacement, windowSize: NSSize) -> NSPoint {
        let savedOrigin = NSPoint(x: CGFloat(placement.originX), y: CGFloat(placement.originY))
        let savedSize = NSSize(width: CGFloat(max(placement.width, 1)), height: CGFloat(max(placement.height, 1)))
        let savedCenter = NSPoint(x: savedOrigin.x + savedSize.width / 2, y: savedOrigin.y + savedSize.height / 2)

        guard let targetScreen = screen(matching: placement.screenID)
            ?? screen(containing: savedCenter)
            ?? NSScreen.main
            ?? NSScreen.screens.first
        else {
            return savedOrigin
        }

        let visibleFrame = targetScreen.visibleFrame
        if let screenID = placement.screenID, screenID == screenIdentifier(for: targetScreen) {
            return clampedOrigin(savedOrigin, windowSize: windowSize, visibleFrame: visibleFrame)
        }

        guard let previousVisibleFrame = placement.screenVisibleFrame?.nsRect,
              previousVisibleFrame.width > 0,
              previousVisibleFrame.height > 0
        else {
            return clampedOrigin(savedOrigin, windowSize: windowSize, visibleFrame: visibleFrame)
        }

        let relativeX = normalizedPosition(
            savedOrigin.x - previousVisibleFrame.minX,
            availableLength: previousVisibleFrame.width - savedSize.width,
            fallback: 1
        )
        let relativeY = normalizedPosition(
            savedOrigin.y - previousVisibleFrame.minY,
            availableLength: previousVisibleFrame.height - savedSize.height,
            fallback: 1
        )

        let availableWidth = max(visibleFrame.width - windowSize.width, 0)
        let availableHeight = max(visibleFrame.height - windowSize.height, 0)
        let migratedOrigin = NSPoint(
            x: visibleFrame.minX + availableWidth * relativeX,
            y: visibleFrame.minY + availableHeight * relativeY
        )

        return clampedOrigin(migratedOrigin, windowSize: windowSize, visibleFrame: visibleFrame)
    }

    private func defaultOrigin(for windowSize: NSSize) -> NSPoint {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return NSPoint(x: 200, y: 200)
        }

        let visibleFrame = screen.visibleFrame
        return clampedOrigin(
            NSPoint(x: visibleFrame.maxX - windowSize.width - restoreMargin, y: visibleFrame.maxY - windowSize.height - restoreMargin),
            windowSize: windowSize,
            visibleFrame: visibleFrame
        )
    }

    private func normalizedPosition(_ position: CGFloat, availableLength: CGFloat, fallback: CGFloat) -> CGFloat {
        guard availableLength > 1 else { return fallback }
        return min(max(position / availableLength, 0), 1)
    }

    private func clampedOrigin(_ origin: NSPoint, windowSize: NSSize, visibleFrame: NSRect) -> NSPoint {
        let minX = visibleFrame.minX + restoreMargin
        let maxX = visibleFrame.maxX - windowSize.width - restoreMargin
        let minY = visibleFrame.minY + restoreMargin
        let maxY = visibleFrame.maxY - windowSize.height - restoreMargin

        let x = maxX >= minX ? min(max(origin.x, minX), maxX) : visibleFrame.midX - windowSize.width / 2
        let y = maxY >= minY ? min(max(origin.y, minY), maxY) : visibleFrame.midY - windowSize.height / 2

        return NSPoint(x: x, y: y)
    }

    private func persistWindowPlacement(for window: NSWindow) {
        let frame = window.frame
        let screen = window.screen ?? screen(containing: frame.center) ?? NSScreen.main ?? NSScreen.screens.first
        let placement = OverlayWindowPlacement(
            originX: Double(frame.origin.x),
            originY: Double(frame.origin.y),
            width: Double(frame.width),
            height: Double(frame.height),
            screenID: screen.flatMap(screenIdentifier(for:)),
            screenVisibleFrame: screen.map { OverlayWindowFrame($0.visibleFrame) }
        )

        guard placement != settingsStore.settings.overlayWindowPlacement else { return }
        settingsStore.updateOverlayWindowPlacement(placement)
    }

    private func screen(matching screenID: String?) -> NSScreen? {
        guard let screenID else { return nil }
        return NSScreen.screens.first { screenIdentifier(for: $0) == screenID }
    }

    private func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    private func screenIdentifier(for screen: NSScreen) -> String? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return number.stringValue
    }
}

extension OverlayWindowController: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        persistWindowPlacement(for: window)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        persistWindowPlacement(for: window)
    }
}

/// Non-activating panel for the floating overlay.
private class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isKeyWindow, let responder = firstResponder {
            return responder.performKeyEquivalent(with: event)
        }
        return super.performKeyEquivalent(with: event)
    }
}

private extension OverlayWindowFrame {
    init(_ rect: NSRect) {
        self.init(x: Double(rect.origin.x), y: Double(rect.origin.y), width: Double(rect.width), height: Double(rect.height))
    }

    var nsRect: NSRect {
        NSRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
    }
}

private extension NSRect {
    var center: NSPoint {
        NSPoint(x: midX, y: midY)
    }
}
