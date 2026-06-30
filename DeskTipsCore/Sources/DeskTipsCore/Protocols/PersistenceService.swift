import Foundation

/// Bundles active items, completed items, and categories for atomic persistence.
public struct TodoStoreState: Codable, Sendable {
    public var items: [TodoItem]
    public var completedItems: [TodoItem]
    public var categories: [Category]

    public init(
        items: [TodoItem] = [],
        completedItems: [TodoItem] = [],
        categories: [Category] = []
    ) {
        self.items = items
        self.completedItems = completedItems
        self.categories = categories
    }
}

/// Abstraction for todo persistence. Inject a test double for unit tests.
public protocol PersistenceService {
    func load() -> [TodoItem]
    func save(_ items: [TodoItem])
    func loadState() -> TodoStoreState
    func saveState(_ state: TodoStoreState)
}

// MARK: - Default implementations (backward compatible)

public extension PersistenceService {
    func loadState() -> TodoStoreState {
        TodoStoreState(items: load())
    }

    func saveState(_ state: TodoStoreState) {
        save(state.items)
    }
}

/// UserDefaults-backed persistence using JSON encoding.
public struct UserDefaultsPersistence: PersistenceService, @unchecked Sendable {
    private let key = "com.desktips.todos"
    private let stateKey = "com.desktips.storeState"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> [TodoItem] {
        guard let data = defaults.data(forKey: key),
              let items = try? JSONDecoder().decode([TodoItem].self, from: data)
        else { return [] }
        return items
    }

    public func save(_ items: [TodoItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: key)
    }

    public func loadState() -> TodoStoreState {
        if let data = defaults.data(forKey: stateKey),
           let state = try? JSONDecoder().decode(TodoStoreState.self, from: data) {
            // Auto-migrate: add default categories if empty
            var migrated = state
            if migrated.categories.isEmpty {
                migrated.categories = defaultCategories
            }
            return migrated
        }
        // Migrate from legacy format
        var legacy = TodoStoreState(items: load())
        legacy.categories = defaultCategories
        return legacy
    }

    public func saveState(_ state: TodoStoreState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: stateKey)
    }
}
