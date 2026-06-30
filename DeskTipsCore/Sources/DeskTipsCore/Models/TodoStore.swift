import Foundation
import SwiftUI

/// Central observable store for todo items and categories. Auto-saves on every mutation.
@MainActor
public final class TodoStore: ObservableObject {
    @Published public private(set) var items: [TodoItem] = []
    @Published public private(set) var completedItems: [TodoItem] = []
    @Published public private(set) var categories: [Category] = []

    private let persistence: PersistenceService

    public init(persistence: PersistenceService = UserDefaultsPersistence()) {
        self.persistence = persistence
        let state = persistence.loadState()
        self.items = state.items
        self.completedItems = state.completedItems
        self.categories = state.categories
    }

    // MARK: - Todo Mutations

    public func add(
        title: String,
        categoryID: UUID? = nil,
        dueDate: Date? = nil,
        priority: Priority = .medium
    ) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(TodoItem(title: trimmed, categoryID: categoryID, dueDate: dueDate, priority: priority))
        save()
    }

    public func toggle(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].toggle()
        save()
    }

    public func uncomplete(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        if items[index].isCompleted {
            items[index].toggle()
            save()
        }
    }

    public func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        save()
    }

    public func remove(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    public func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        save()
    }

    public func updateTitle(id: UUID, newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].title = trimmed
        save()
    }

    public func updateCategory(id: UUID, categoryID: UUID?) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].categoryID = categoryID
        save()
    }

    public func updateDueDate(id: UUID, dueDate: Date?) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].dueDate = dueDate
        save()
    }

    public func updatePriority(id: UUID, priority: Priority) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].priority = priority
        save()
    }

    public func clearCompleted() {
        let completed = items.filter { $0.isCompleted }
        guard !completed.isEmpty else { return }
        items.removeAll { $0.isCompleted }
        completedItems.insert(contentsOf: completed, at: 0)
        save()
    }

    // MARK: - Category Mutations

    public func addCategory(name: String, color: String, iconName: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let order = (categories.map(\.sortOrder).max() ?? -1) + 1
        categories.append(Category(name: trimmed, color: color, iconName: iconName, sortOrder: order))
        save()
    }

    public func updateCategory(id: UUID, name: String, color: String, iconName: String) {
        guard let index = categories.firstIndex(where: { $0.id == id }) else { return }
        categories[index].name = name
        categories[index].color = color
        categories[index].iconName = iconName
        save()
    }

    public func removeCategory(id: UUID) {
        categories.removeAll { $0.id == id }
        // Unset categoryID for items in this category
        for i in items.indices where items[i].categoryID == id {
            items[i].categoryID = nil
        }
        for i in completedItems.indices where completedItems[i].categoryID == id {
            completedItems[i].categoryID = nil
        }
        save()
    }

    public func moveCategory(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
        for i in categories.indices { categories[i].sortOrder = i }
        save()
    }

    // MARK: - Queries

    public func itemsForCategory(_ categoryID: UUID?) -> [TodoItem] {
        items.filter { $0.categoryID == categoryID }
    }

    public var uncategorizedItems: [TodoItem] {
        items.filter { $0.categoryID == nil }
    }

    public func category(for item: TodoItem) -> Category? {
        guard let id = item.categoryID else { return nil }
        return categories.first { $0.id == id }
    }

    public var activeCount: Int {
        items.filter { !$0.isCompleted }.count
    }

    public var completedCount: Int {
        items.filter { $0.isCompleted }.count
    }

    public var overdueItems: [TodoItem] {
        items.filter { $0.isOverdue }
    }

    /// Items due within the given time interval from now.
    public func itemsDueSoon(within interval: TimeInterval) -> [TodoItem] {
        let deadline = Date().addingTimeInterval(interval)
        return items.filter { item in
            guard let due = item.dueDate, !item.isCompleted else { return false }
            return due <= deadline && due >= Date()
        }
    }

    // MARK: - History

    public func restoreFromHistory(id: UUID) {
        guard let index = completedItems.firstIndex(where: { $0.id == id }) else { return }
        var restored = completedItems[index]
        restored.toggle()
        completedItems.remove(at: index)
        items.append(restored)
        save()
    }

    public func deleteFromHistory(id: UUID) {
        completedItems.removeAll { $0.id == id }
        save()
    }

    public func clearHistory() {
        completedItems.removeAll()
        save()
    }

    public var historyByDate: [(date: Date, items: [TodoItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: completedItems) { item -> Date in
            guard let completedAt = item.completedAt else {
                return calendar.startOfDay(for: item.createdAt)
            }
            return calendar.startOfDay(for: completedAt)
        }
        return grouped.map { (date: $0.key, items: $0.value) }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Persistence

    private func save() {
        persistence.saveState(TodoStoreState(items: items, completedItems: completedItems, categories: categories))
    }
}
