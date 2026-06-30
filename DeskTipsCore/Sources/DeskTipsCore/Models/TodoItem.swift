import Foundation

/// A single todo item.
public struct TodoItem: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var isCompleted: Bool
    public var createdAt: Date
    public var completedAt: Date?
    public var categoryID: UUID?
    public var dueDate: Date?
    public var priority: Priority

    public init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        categoryID: UUID? = nil,
        dueDate: Date? = nil,
        priority: Priority = .medium
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = isCompleted ? createdAt : nil
        self.categoryID = categoryID
        self.dueDate = dueDate
        self.priority = priority
    }

    /// Toggle completion state.
    public mutating func toggle() {
        isCompleted.toggle()
        completedAt = isCompleted ? Date() : nil
    }

    /// Whether the due date has passed.
    public var isOverdue: Bool {
        guard let due = dueDate, !isCompleted else { return false }
        return due < Date()
    }

    /// Formatted countdown string for the due date.
    public var dueDateLabel: String? {
        guard let due = dueDate else { return nil }
        let calendar = Calendar.current
        if isOverdue { return "已过期" }
        if calendar.isDateInToday(due) {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return "今天 \(f.string(from: due))"
        }
        if calendar.isDateInTomorrow(due) { return "明天" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: due)).day ?? 0
        if days <= 7 { return "\(days)天后" }
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: due)
    }
}
