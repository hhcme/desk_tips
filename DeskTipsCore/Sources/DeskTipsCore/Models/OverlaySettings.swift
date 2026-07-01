import Foundation

/// Display mode for the floating overlay window.
public enum OverlayDisplayMode: String, Codable, Sendable, CaseIterable {
    case glass        // macOS 26 Liquid Glass effect
    case frosted      // Traditional frosted blur effect
    case transparent  // Plain color background
}

/// Stored rectangle in global screen coordinates.
public struct OverlayWindowFrame: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Stored overlay window placement, including the screen it was last seen on.
public struct OverlayWindowPlacement: Codable, Sendable, Equatable {
    public var originX: Double
    public var originY: Double
    public var width: Double
    public var height: Double
    public var screenID: String?
    public var screenVisibleFrame: OverlayWindowFrame?

    public init(
        originX: Double,
        originY: Double,
        width: Double,
        height: Double,
        screenID: String? = nil,
        screenVisibleFrame: OverlayWindowFrame? = nil
    ) {
        self.originX = originX
        self.originY = originY
        self.width = width
        self.height = height
        self.screenID = screenID
        self.screenVisibleFrame = screenVisibleFrame
    }
}

/// Persisted overlay display settings.
public struct OverlaySettings: Codable, Sendable, Equatable {
    public var displayMode: OverlayDisplayMode
    /// Intensity for glass mode (0.0 – 1.0).
    public var glassIntensity: Double
    /// Transparency amount for transparent mode (0.3 – 1.0). The persisted key name is kept for compatibility.
    public var transparentOpacity: Double
    /// Whether the overlay window is visible.
    public var isVisible: Bool
    /// Custom title for the overlay window.
    public var overlayTitle: String
    /// Whether the overlay title is shown.
    public var showsOverlayTitle: Bool
    /// Last known overlay window placement.
    public var overlayWindowPlacement: OverlayWindowPlacement?
    /// Default reminder offset in seconds before due date. 0 = no reminder.
    public var defaultReminderOffset: TimeInterval

    public init(
        displayMode: OverlayDisplayMode = .glass,
        glassIntensity: Double = 0.7,
        transparentOpacity: Double = 0.85,
        isVisible: Bool = true,
        overlayTitle: String = "DeskTips",
        showsOverlayTitle: Bool = true,
        overlayWindowPlacement: OverlayWindowPlacement? = nil,
        defaultReminderOffset: TimeInterval = 900
    ) {
        self.displayMode = displayMode
        self.glassIntensity = glassIntensity
        self.transparentOpacity = transparentOpacity
        self.isVisible = isVisible
        self.overlayTitle = overlayTitle
        self.showsOverlayTitle = showsOverlayTitle
        self.overlayWindowPlacement = overlayWindowPlacement
        self.defaultReminderOffset = defaultReminderOffset
    }

    private enum CodingKeys: String, CodingKey {
        case displayMode
        case glassIntensity
        case transparentOpacity
        case isVisible
        case overlayTitle
        case showsOverlayTitle
        case overlayWindowPlacement
        case defaultReminderOffset
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayMode = try container.decodeIfPresent(OverlayDisplayMode.self, forKey: .displayMode) ?? .glass
        glassIntensity = try container.decodeIfPresent(Double.self, forKey: .glassIntensity) ?? 0.7
        transparentOpacity = try container.decodeIfPresent(Double.self, forKey: .transparentOpacity) ?? 0.85
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        overlayTitle = try container.decodeIfPresent(String.self, forKey: .overlayTitle) ?? "DeskTips"
        showsOverlayTitle = try container.decodeIfPresent(Bool.self, forKey: .showsOverlayTitle) ?? true
        overlayWindowPlacement = try container.decodeIfPresent(OverlayWindowPlacement.self, forKey: .overlayWindowPlacement)
        defaultReminderOffset = try container.decodeIfPresent(TimeInterval.self, forKey: .defaultReminderOffset) ?? 900
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(displayMode, forKey: .displayMode)
        try container.encode(glassIntensity, forKey: .glassIntensity)
        try container.encode(transparentOpacity, forKey: .transparentOpacity)
        try container.encode(isVisible, forKey: .isVisible)
        try container.encode(overlayTitle, forKey: .overlayTitle)
        try container.encode(showsOverlayTitle, forKey: .showsOverlayTitle)
        try container.encodeIfPresent(overlayWindowPlacement, forKey: .overlayWindowPlacement)
        try container.encode(defaultReminderOffset, forKey: .defaultReminderOffset)
    }
}
