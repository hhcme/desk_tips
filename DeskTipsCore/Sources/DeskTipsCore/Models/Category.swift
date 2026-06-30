import Foundation

/// Priority level for a todo item.
public enum Priority: String, Codable, Sendable, CaseIterable, Comparable {
    case low
    case medium
    case high

    public var sortValue: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }

    public static func < (lhs: Priority, rhs: Priority) -> Bool {
        lhs.sortValue < rhs.sortValue
    }
}

/// A category for organizing todo items.
public struct Category: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var color: String       // hex: "#3B82F6"
    public var iconName: String    // SF Symbol name
    public var sortOrder: Int

    public init(
        id: UUID = UUID(),
        name: String,
        color: String = "#3B82F6",
        iconName: String = "folder.fill",
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.iconName = iconName
        self.sortOrder = sortOrder
    }
}

/// Default categories for new installs.
public let defaultCategories: [Category] = [
    Category(name: "工作", color: "#3B82F6", iconName: "briefcase.fill", sortOrder: 0),
    Category(name: "生活", color: "#10B981", iconName: "house.fill", sortOrder: 1),
    Category(name: "学习", color: "#8B5CF6", iconName: "book.fill", sortOrder: 2),
]
