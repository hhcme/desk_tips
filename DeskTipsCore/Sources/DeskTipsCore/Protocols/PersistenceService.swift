import Foundation

/// Bundles active and completed items for atomic persistence.
public struct TodoStoreState: Codable, Sendable {
    public var items: [TodoItem]
    public var completedItems: [TodoItem]

    public init(items: [TodoItem] = [], completedItems: [TodoItem] = []) {
        self.items = items
        self.completedItems = completedItems
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
/// UserDefaults is thread-safe; @unchecked Sendable is safe here.
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
        else {
            return []
        }
        return items
    }

    public func save(_ items: [TodoItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: key)
    }

    public func loadState() -> TodoStoreState {
        // Try new state format first, fall back to legacy
        if let data = defaults.data(forKey: stateKey),
           let state = try? JSONDecoder().decode(TodoStoreState.self, from: data) {
            return state
        }
        // Migrate from legacy format
        return TodoStoreState(items: load())
    }

    public func saveState(_ state: TodoStoreState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: stateKey)
    }
}
