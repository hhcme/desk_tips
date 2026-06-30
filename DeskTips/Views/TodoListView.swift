import SwiftUI
import DeskTipsCore

/// Full-featured active todo list for the main window "待办" tab.
struct TodoListView: View {
    @ObservedObject var store: TodoStore
    @State private var newTodoText = ""
    @State private var editingID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("待办事项")
                    .font(.headline)
                Spacer()
                Text("\(store.items.count) 项")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // List
            if store.items.isEmpty {
                emptyState
            } else {
                todoList
            }

            Divider()

            // Add bar
            addBar
                .padding(12)
        }
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
            Text("在下方添加新的待办事项")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Todo List

    private var todoList: some View {
        List {
            ForEach(store.items.filter { !$0.isCompleted }) { item in
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
            // Complete button
            Button {
                store.toggle(item)
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            // Title (editable on double-click)
            if editingID == item.id {
                TextField("", text: Binding(
                    get: { item.title },
                    set: { store.updateTitle(id: item.id, newTitle: $0) }
                ))
                .textFieldStyle(.plain)
                .onSubmit { editingID = nil }
            } else {
                Text(item.title)
                    .font(.body)
                    .onTapGesture(count: 2) {
                        editingID = item.id
                    }
            }

            Spacer()

            // Edit hint
            if editingID != item.id {
                Button {
                    editingID = item.id
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Add Bar

    private var addBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.tint)
                .font(.title3)

            TextField("添加新待办…", text: $newTodoText)
                .textFieldStyle(.plain)
                .onSubmit { addTodo() }

            Button("添加") {
                addTodo()
            }
            .buttonStyle(.borderedProminent)
            .disabled(newTodoText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func addTodo() {
        store.add(title: newTodoText)
        newTodoText = ""
    }
}
