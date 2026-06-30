import Foundation
import Testing
@testable import DeskTipsCore

@Suite("Category tests")
struct CategoryTests {

    @Test("Init sets defaults")
    func initDefaults() {
        let cat = Category(name: "Test")
        #expect(cat.name == "Test")
        #expect(cat.color == "#3B82F6")
        #expect(cat.iconName == "folder.fill")
        #expect(cat.sortOrder == 0)
    }

    @Test("Codable round-trip")
    func codableRoundTrip() throws {
        let original = Category(name: "Work", color: "#FF0000", iconName: "briefcase.fill", sortOrder: 5)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Category.self, from: data)
        #expect(decoded == original)
    }

    @Test("Default categories exist")
    func defaultCategoriesExist() {
        #expect(defaultCategories.count == 3)
        #expect(defaultCategories[0].name == "工作")
        #expect(defaultCategories[1].name == "生活")
        #expect(defaultCategories[2].name == "学习")
    }

    @Test("Equatable")
    func equatable() {
        let a = Category(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "A")
        let b = Category(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "A")
        let c = Category(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "A")
        #expect(a == b)
        #expect(a != c)
    }
}
