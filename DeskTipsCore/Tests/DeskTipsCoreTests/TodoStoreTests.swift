import Testing
import Foundation
@testable import DeskTipsCore

/// In-memory persistence for testing.
final class MockPersistence: PersistenceService, @unchecked Sendable {
    var stored: [TodoItem] = []
    var storedState: TodoStoreState?
    private(set) var saveCount = 0

    func load() -> [TodoItem] { stored }

    func save(_ items: [TodoItem]) {
        stored = items
        saveCount += 1
    }

    func loadState() -> TodoStoreState {
        storedState ?? TodoStoreState(items: stored, categories: defaultCategories)
    }

    func saveState(_ state: TodoStoreState) {
        storedState = state
        stored = state.items
        saveCount += 1
    }
}

@MainActor
@Suite("TodoStore tests")
struct TodoStoreTests {

    // MARK: - Basic CRUD

    @Test("Add with category, due date, priority")
    func addFull() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        let catID = UUID()
        let due = Date().addingTimeInterval(3600)
        store.add(title: "Full item", categoryID: catID, dueDate: due, priority: .high)
        let item = store.items[0]
        #expect(item.title == "Full item")
        #expect(item.categoryID == catID)
        #expect(item.dueDate != nil)
        #expect(item.priority == .high)
    }

    @Test("Toggle marks item complete in place")
    func toggleComplete() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        store.add(title: "Toggle me")
        store.toggle(store.items[0])
        #expect(store.items[0].isCompleted == true)
        #expect(store.items[0].completedAt != nil)
    }

    @Test("Clear completed moves to history")
    func clearCompleted() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        store.add(title: "Active")
        store.add(title: "Done")
        store.toggle(store.items[1])
        store.clearCompleted()
        #expect(store.items.count == 1)
        #expect(store.completedItems.count == 1)
    }

    // MARK: - Category CRUD

    @Test("Add category")
    func addCategory() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        let count = store.categories.count
        store.addCategory(name: "Test", color: "#FF0000", iconName: "star")
        #expect(store.categories.count == count + 1)
        #expect(store.categories.last?.name == "Test")
    }

    @Test("Update category")
    func updateCategory() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        let cat = store.categories[0]
        store.updateCategory(id: cat.id, name: "Updated", color: "#00FF00", iconName: "heart")
        #expect(store.categories[0].name == "Updated")
        #expect(store.categories[0].color == "#00FF00")
    }

    @Test("Remove category unsets items")
    func removeCategory() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        let cat = store.categories[0]
        store.add(title: "Categorized", categoryID: cat.id)
        #expect(store.items[0].categoryID == cat.id)
        store.removeCategory(id: cat.id)
        #expect(store.items[0].categoryID == nil)
    }

    @Test("Filter by category")
    func filterByCategory() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        let cat = store.categories[0]
        store.add(title: "In cat", categoryID: cat.id)
        store.add(title: "No cat")
        let filtered = store.itemsForCategory(cat.id)
        #expect(filtered.count == 1)
        #expect(filtered[0].title == "In cat")
        #expect(store.uncategorizedItems.count == 1)
    }

    // MARK: - Due Date Queries

    @Test("Overdue items")
    func overdue() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        store.add(title: "Overdue", dueDate: Date().addingTimeInterval(-3600))
        store.add(title: "Future", dueDate: Date().addingTimeInterval(3600))
        store.add(title: "No date")
        #expect(store.overdueItems.count == 1)
        #expect(store.overdueItems[0].title == "Overdue")
    }

    @Test("Items due soon")
    func dueSoon() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        store.add(title: "Soon", dueDate: Date().addingTimeInterval(600))  // 10 min
        store.add(title: "Later", dueDate: Date().addingTimeInterval(7200))  // 2 hours
        let soon = store.itemsDueSoon(within: 900)  // within 15 min
        #expect(soon.count == 1)
        #expect(soon[0].title == "Soon")
    }

    @Test("History grouped by date")
    func historyByDate() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        store.add(title: "A")
        store.add(title: "B")
        store.toggle(store.items[0])  // A completed
        store.toggle(store.items[1])  // B completed
        store.clearCompleted()
        let groups = store.historyByDate
        #expect(groups.count >= 1)
        #expect(groups[0].items.count == 2)
    }

    @Test("SaveState round trip with categories")
    func saveStateRoundTrip() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        store.add(title: "Test", categoryID: store.categories[0].id)
        store.addCategory(name: "Custom", color: "#ABC", iconName: "star")
        let store2 = TodoStore(persistence: mock)
        #expect(store2.items.count == 1)
        #expect(store2.categories.count == store.categories.count)
        #expect(store2.items[0].categoryID == store.items[0].categoryID)
    }
}
