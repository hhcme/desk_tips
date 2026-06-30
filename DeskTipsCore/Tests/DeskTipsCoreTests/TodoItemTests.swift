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
    }

    @Test("Init with isCompleted sets completedAt")
    func initCompleted() {
        let now = Date()
        let item = TodoItem(title: "Done", isCompleted: true, createdAt: now)
        #expect(item.isCompleted == true)
        #expect(item.completedAt == now)
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

    @Test("Codable round-trip preserves data")
    func codableRoundTrip() throws {
        let original = TodoItem(title: "Round trip", isCompleted: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TodoItem.self, from: data)
        #expect(decoded == original)
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
