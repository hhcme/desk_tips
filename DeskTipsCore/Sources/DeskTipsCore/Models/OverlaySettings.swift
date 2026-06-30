import Foundation

/// Display mode for the floating overlay window.
public enum OverlayDisplayMode: String, Codable, Sendable, CaseIterable {
    case glass        // macOS 26 Liquid Glass effect
    case transparent  // Plain color background
}

/// Persisted overlay display settings.
public struct OverlaySettings: Codable, Sendable, Equatable {
    public var displayMode: OverlayDisplayMode
    /// Intensity for glass mode (0.0 – 1.0).
    public var glassIntensity: Double
    /// Opacity for transparent mode (0.3 – 1.0).
    public var transparentOpacity: Double
    /// Whether the overlay window is visible.
    public var isVisible: Bool
    /// Custom title for the overlay window.
    public var overlayTitle: String

    public init(
        displayMode: OverlayDisplayMode = .glass,
        glassIntensity: Double = 0.7,
        transparentOpacity: Double = 0.85,
        isVisible: Bool = true,
        overlayTitle: String = "DeskTips"
    ) {
        self.displayMode = displayMode
        self.glassIntensity = glassIntensity
        self.transparentOpacity = transparentOpacity
        self.isVisible = isVisible
        self.overlayTitle = overlayTitle
    }
}
