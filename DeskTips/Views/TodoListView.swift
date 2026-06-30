import SwiftUI
import DeskTipsCore

/// Enhanced todo list with category filter, priority, due date.
struct TodoListView: View {
    @ObservedObject var store: TodoStore
    @State private var newTodoText = ""
    @State private var selectedCategoryID: UUID? = nil
    @State private var selectedPriority: Priority = .medium
    @State private var hasDueDate = false
    @State private var dueDate = Date().addingTimeInterval(3600)
    @State private var filterCategoryID: UUID? = nil  // nil = all

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("待办事项")
                    .font(.headline)
                Spacer()
                // Category filter
                Picker("", selection: $filterCategoryID) {
                    Text("全部").tag(UUID?.none)
                    ForEach(store.categories) { cat in
                        Label(cat.name, systemImage: cat.iconName).tag(UUID?.some(cat.id))
                    }
                    Text("未分类").tag(UUID?.some(UUID(uuidString: "00000000-0000-0000-0000-000000000000")!))
                }
                .frame(width: 120)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // Add form
            addForm
                .padding(12)

            Divider()

            // List
            if filteredItems.isEmpty {
                emptyState
            } else {
                todoList
            }
        }
    }

    // MARK: - Add Form

    private var addForm: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.tint)
                TextField("添加新待办…", text: $newTodoText)
                    .textFieldStyle(.plain)
                    .onSubmit { addTodo() }
                Button("添加") { addTodo() }
                    .buttonStyle(.borderedProminent)
                    .disabled(newTodoText.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            HStack(spacing: 12) {
                // Category picker
                Picker("", selection: $selectedCategoryID) {
                    Text("无分类").tag(UUID?.none)
                    ForEach(store.categories) { cat in
                        Label(cat.name, systemImage: cat.iconName).tag(UUID?.some(cat.id))
                    }
                }
                .frame(width: 100)

                // Priority
                Picker("", selection: $selectedPriority) {
                    Text("高").tag(Priority.high)
                    Text("中").tag(Priority.medium)
                    Text("低").tag(Priority.low)
                }
                .frame(width: 70)

                // Due date
                Toggle("截止", isOn: $hasDueDate)
                    .fixedSize()
                if hasDueDate {
                    DatePicker("", selection: $dueDate)
                        .labelsHidden()
                        .frame(width: 160)
                }
            }
            .font(.caption)
        }
    }

    // MARK: - List

    private var todoList: some View {
        List {
            ForEach(filteredItems) { item in
                todoRow(item)
            }
            .onMove { from, to in
                store.move(from: from, to: to)
            }
            .onDelete { offsets in
                store.remove(at: offsets)
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private func todoRow(_ item: TodoItem) -> some View {
        HStack(spacing: 10) {
            // Complete
            Button { store.toggle(item) } label: {
                Image(systemName: "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            // Priority dot
            Circle()
                .fill(priorityColor(item.priority))
                .frame(width: 8, height: 8)

            // Title
            Text(item.title)
                .font(.body)

            Spacer()

            // Category tag
            if let cat = store.category(for: item) {
                Text(cat.name)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: cat.color).opacity(0.15))
                    .clipShape(Capsule())
            }

            // Due date
            if let label = item.dueDateLabel {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(item.isOverdue ? .red : .secondary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("暂无待办")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var filteredItems: [TodoItem] {
        store.items.filter { item in
            if let filterID = filterCategoryID {
                // Special UUID for "uncategorized"
                if filterID == UUID(uuidString: "00000000-0000-0000-0000-000000000000") {
                    return item.categoryID == nil
                }
                return item.categoryID == filterID
            }
            return true
        }
    }

    private func addTodo() {
        store.add(title: newTodoText, categoryID: selectedCategoryID, dueDate: hasDueDate ? dueDate : nil, priority: selectedPriority)
        newTodoText = ""
    }

    private func priorityColor(_ priority: Priority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
}
