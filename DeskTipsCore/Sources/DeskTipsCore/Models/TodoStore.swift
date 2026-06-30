import Foundation
import SwiftUI

/// Central observable store for todo items. Auto-saves on every mutation.
/// Active items in `items`, completed items archived in `completedItems`.
@MainActor
public final class TodoStore: ObservableObject {
    /// All todo items (including completed ones that haven't been cleaned up yet).
    @Published public private(set) var items: [TodoItem] = []

    /// Completed items archived by cleanup/completion.
    @Published public private(set) var completedItems: [TodoItem] = []

    private let persistence: PersistenceService

    public init(persistence: PersistenceService = UserDefaultsPersistence()) {
        self.persistence = persistence
        let state = persistence.loadState()
        self.items = state.items
        self.completedItems = state.completedItems
    }

    // MARK: - Active Item Mutations

    public func add(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(TodoItem(title: trimmed))
        save()
    }

    /// Toggle completion state IN PLACE — does NOT move to history.
    /// Completed items stay in `items` with isCompleted=true until cleaned up.
    public func toggle(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].toggle()
        save()
    }

    /// Restore a completed item back to active (un-complete).
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

    /// Move all completed items from `items` to `completedItems` (archive to history).
    public func clearCompleted() {
        let completed = items.filter { $0.isCompleted }
        guard !completed.isEmpty else { return }
        items.removeAll { $0.isCompleted }
        completedItems.insert(contentsOf: completed, at: 0)
        save()
    }

    // MARK: - History Mutations

    public func restoreFromHistory(id: UUID) {
        guard let index = completedItems.firstIndex(where: { $0.id == id }) else { return }
        var restored = completedItems[index]
        restored.toggle()  // sets isCompleted=false, completedAt=nil
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

    // MARK: - History Queries

    /// Completed items grouped by date (day), sorted newest first.
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

    /// Number of active (non-completed) items.
    public var activeCount: Int {
        items.filter { !$0.isCompleted }.count
    }

    /// Number of completed items still in the list (not yet cleaned up).
    public var completedCount: Int {
        items.filter { $0.isCompleted }.count
    }

    // MARK: - Persistence

    private func save() {
        persistence.saveState(TodoStoreState(items: items, completedItems: completedItems))
    }
}
