import Foundation
import Testing
@testable import DeskTipsCore

@Suite("TodoItem tests")
struct TodoItemTests {

    @Test("Init sets default values correctly")
    func initDefaults() {
        let item = TodoItem(title: "Buy milk")
        #expect(item.title == "Buy milk")
        #expect(item.isCompleted == false)
        #expect(item.completedAt == nil)
        #expect(item.categoryID == nil)
        #expect(item.dueDate == nil)
        #expect(item.priority == .medium)
    }

    @Test("Init with all fields")
    func initFull() {
        let catID = UUID()
        let due = Date()
        let item = TodoItem(title: "Full", categoryID: catID, dueDate: due, priority: .high)
        #expect(item.categoryID == catID)
        #expect(item.dueDate == due)
        #expect(item.priority == .high)
    }

    @Test("Toggle flips completion state")
    func toggle() {
        var item = TodoItem(title: "Test")
        #expect(item.isCompleted == false)
        item.toggle()
        #expect(item.isCompleted == true)
        #expect(item.completedAt != nil)
        item.toggle()
        #expect(item.isCompleted == false)
        #expect(item.completedAt == nil)
    }

    @Test("isOverdue")
    func isOverdue() {
        let past = TodoItem(title: "Past", dueDate: Date().addingTimeInterval(-3600))
        #expect(past.isOverdue == true)
        let future = TodoItem(title: "Future", dueDate: Date().addingTimeInterval(3600))
        #expect(future.isOverdue == false)
        let noDate = TodoItem(title: "No date")
        #expect(noDate.isOverdue == false)
        var completedPast = TodoItem(title: "Done past", dueDate: Date().addingTimeInterval(-3600))
        completedPast.toggle()
        #expect(completedPast.isOverdue == false)
    }

    @Test("dueDateLabel")
    func dueDateLabel() {
        let noDate = TodoItem(title: "No date")
        #expect(noDate.dueDateLabel == nil)
        let past = TodoItem(title: "Past", dueDate: Date().addingTimeInterval(-3600))
        #expect(past.dueDateLabel == "已过期")
    }

    @Test("Priority comparison")
    func priorityCompare() {
        #expect(Priority.low < Priority.medium)
        #expect(Priority.medium < Priority.high)
    }

    @Test("Codable round-trip preserves new fields")
    func codableRoundTrip() throws {
        let catID = UUID()
        let original = TodoItem(title: "Round trip", categoryID: catID, dueDate: Date(timeIntervalSince1970: 0), priority: .high)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TodoItem.self, from: data)
        #expect(decoded == original)
        #expect(decoded.categoryID == catID)
        #expect(decoded.priority == .high)
    }

    @Test("Equatable works correctly")
    func equatable() {
        let fixedDate = Date(timeIntervalSince1970: 0)
        let a = TodoItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, title: "A", createdAt: fixedDate)
        let b = TodoItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, title: "A", createdAt: fixedDate)
        let c = TodoItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, title: "A", createdAt: fixedDate)
        #expect(a == b)
        #expect(a != c)
    }
}
