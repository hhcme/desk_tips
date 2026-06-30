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
        storedState ?? TodoStoreState(items: stored)
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

    @Test("Store loads from persistence on init")
    func loadsOnInit() {
        let mock = MockPersistence()
        mock.stored = [TodoItem(title: "Loaded")]
        let store = TodoStore(persistence: mock)
        #expect(store.items.count == 1)
        #expect(store.items[0].title == "Loaded")
    }

    @Test("Add appends item and saves")
    func add() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        store.add(title: "New task")
        #expect(store.items.count == 1)
        #expect(store.items[0].title == "New task")
        #expect(mock.saveCount == 1)
    }

    @Test("Add ignores empty and whitespace-only titles")
    func addEmpty() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        store.add(title: "")
        store.add(title: "   ")
        store.add(title: "\n")
        #expect(store.items.isEmpty)
    }

    @Test("Toggle marks item complete in place")
    func toggleComplete() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        store.add(title: "Toggle me")
        let item = store.items[0]
        store.toggle(item)
        // Item stays in items, just marked complete
        #expect(store.items.count == 1)
        #expect(store.items[0].isCompleted == true)
        #expect(store.items[0].completedAt != nil)
    }

    @Test("Toggle marks item incomplete in place")
    func toggleIncomplete() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        store.add(title: "Toggle me")
        store.toggle(store.items[0])
        #expect(store.items[0].isCompleted == true)
        store.toggle(store.items[0])
        #expect(store.items[0].isCompleted == false)
        #expect(store.items[0].completedAt == nil)
    }

    @Test("Clear completed moves completed items to history")
    func clearCompleted() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        store.add(title: "Active")
        store.add(title: "Done")
        store.toggle(store.items[1])
        store.clearCompleted()
        #expect(store.items.count == 1)
        #expect(store.items[0].title == "Active")
        #expect(store.completedItems.count == 1)
        #expect(store.completedItems[0].title == "Done")
    }

    @Test("Restore from history")
    func restoreFromHistory() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        store.add(title: "Will restore")
        let id = store.items[0].id
        store.toggle(store.items[0])
        store.clearCompleted()
        #expect(store.completedItems.count == 1)
        store.restoreFromHistory(id: id)
        #expect(store.items.count == 1)
        #expect(store.items[0].isCompleted == false)
        #expect(store.completedItems.isEmpty)
    }

    @Test("Delete from history permanently")
    func deleteFromHistory() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        store.add(title: "Permanent delete")
        let id = store.items[0].id
        store.toggle(store.items[0])
        store.clearCompleted()
        store.deleteFromHistory(id: id)
        #expect(store.completedItems.isEmpty)
        #expect(store.items.isEmpty)
    }

    @Test("Remove at offsets")
    func removeAtOffsets() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        store.add(title: "A")
        store.add(title: "B")
        store.remove(at: IndexSet(integer: 0))
        #expect(store.items.count == 1)
        #expect(store.items[0].title == "B")
    }

    @Test("Remove by id")
    func removeById() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        store.add(title: "To remove")
        let id = store.items[0].id
        store.remove(id: id)
        #expect(store.items.isEmpty)
    }

    @Test("Move reorders items")
    func move() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        store.add(title: "First")
        store.add(title: "Second")
        store.add(title: "Third")
        store.move(from: IndexSet(integer: 0), to: 3)
        #expect(store.items[0].title == "Second")
        #expect(store.items[1].title == "Third")
        #expect(store.items[2].title == "First")
    }

    @Test("Update title")
    func updateTitle() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        store.add(title: "Old")
        let id = store.items[0].id
        store.updateTitle(id: id, newTitle: "New")
        #expect(store.items[0].title == "New")
    }

    @Test("Active and completed counts")
    func counts() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        store.add(title: "Active 1")
        store.add(title: "Active 2")
        store.add(title: "Will complete")
        store.toggle(store.items[2])
        #expect(store.activeCount == 2)
        #expect(store.completedCount == 1)
    }

    @Test("SaveState persists both items and completedItems")
    func saveStateRoundTrip() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        store.add(title: "Active")
        store.add(title: "Will complete")
        store.toggle(store.items[1])
        store.clearCompleted()
        // Create new store from same persistence
        let store2 = TodoStore(persistence: mock)
        #expect(store2.items.count == 1)
        #expect(store2.items[0].title == "Active")
        #expect(store2.completedItems.count == 1)
        #expect(store2.completedItems[0].title == "Will complete")
    }

    @Test("History grouped by date")
    func historyByDate() {
        let mock = MockPersistence()
        let store = TodoStore(persistence: mock)
        store.add(title: "A")
        store.add(title: "B")
        // Toggle both items complete (they stay in items, just marked done)
        store.toggle(store.items[0])  // A completed
        store.toggle(store.items[1])  // B completed
        store.clearCompleted()        // move both to history
        let groups = store.historyByDate
        #expect(groups.count >= 1)
        #expect(groups[0].items.count == 2)
    }
}
