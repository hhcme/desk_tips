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
    @State private var editingItemID: UUID?
    @State private var editTodoText = ""
    @State private var editCategoryID: UUID?
    @State private var editPriority: Priority = .medium
    @State private var editHasDueDate = false
    @State private var editDueDate = Date().addingTimeInterval(3600)
    @State private var detailMode: DetailMode = .hidden
    private let uncategorizedFilterID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    private let completeColumnWidth: CGFloat = 28
    private let priorityColumnWidth: CGFloat = 68
    private let categoryColumnWidth: CGFloat = 112
    private let dueDateColumnWidth: CGFloat = 86
    private let todoTextEditorHeight: CGFloat = 112

    private enum DetailMode: Equatable {
        case hidden
        case adding
        case editing
    }

    var body: some View {
        HStack(spacing: 0) {
            listPane
                .frame(minWidth: isDetailVisible ? 700 : 900, maxWidth: .infinity, maxHeight: .infinity)

            if isDetailVisible {
                Divider()

                detailPane
                    .frame(width: 292)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.9), value: detailMode)
        .onDisappear {
            commitActiveDraft()
        }
    }

    // MARK: - List Pane

    private var listPane: some View {
        VStack(spacing: 0) {
            listHeader

            Divider()

            todoTableHeader

            Divider()

            if filteredItems.isEmpty {
                emptyState
            } else {
                todoList
            }
        }
    }

    private var listHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("待办事项")
                    .font(.headline.weight(.semibold))
                Text("\(filteredItems.count) 项待办")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("", selection: $filterCategoryID) {
                Text("全部").tag(UUID?.none)
                ForEach(store.categories) { cat in
                    Label(cat.name, systemImage: cat.iconName).tag(UUID?.some(cat.id))
                }
                Text("未分类").tag(UUID?.some(uncategorizedFilterID))
            }
            .labelsHidden()
            .controlSize(.small)
            .frame(width: 160)

            if store.completedCount > 0 {
                Button {
                    archiveCompletedTodos()
                } label: {
                    Label("归档已完成", systemImage: "archivebox")
                }
                .controlSize(.small)
                .help("把已完成待办移到历史")
            }

            Button {
                startAddingTodo()
            } label: {
                Label("添加待办", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var todoTableHeader: some View {
        HStack(spacing: 8) {
            tableHeaderText("")
                .frame(width: completeColumnWidth)
            tableHeaderText("待办")
                .frame(maxWidth: .infinity, alignment: .leading)
            tableHeaderText("优先级")
                .frame(width: priorityColumnWidth, alignment: .leading)
            tableHeaderText("分类")
                .frame(width: categoryColumnWidth, alignment: .leading)
            tableHeaderText("截止")
                .frame(width: dueDateColumnWidth, alignment: .leading)
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.12))
    }

    private func tableHeaderText(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    // MARK: - Detail Pane

    private var detailPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Text(detailTitle)
                    .font(.headline.weight(.semibold))

                Spacer()

                Button {
                    cancelDetail()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help("关闭")
            }

            ScrollView {
                todoForm
                    .padding(.top, 18)
                    .padding(.bottom, 12)
            }
            .scrollIndicators(.automatic)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            todoActionBar
        }
        .padding(18)
        .background(.quaternary.opacity(0.18))
    }

    private var todoForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("内容")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                todoTextEditor
            }

            formField("分类") {
                categoryPicker(selection: categoryBinding)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            formField("优先级") {
                priorityPicker(selection: priorityBinding)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 10) {
                Toggle("设置截止时间", isOn: hasDueDateBinding)
                    .toggleStyle(.checkbox)
                    .controlSize(.regular)

                if activeHasDueDate {
                    DatePicker("截止时间", selection: dueDateBinding)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

        }
        .animation(.spring(response: 0.26, dampingFraction: 0.9), value: activeHasDueDate)
        .animation(.spring(response: 0.24, dampingFraction: 0.88), value: isEditing)
    }

    private var todoActionBar: some View {
        VStack(spacing: 12) {
            Divider()

            if isEditing {
                HStack(spacing: 10) {
                    Button("取消") {
                        cancelEditing()
                    }

                    Button {
                        saveTodo()
                    } label: {
                        Label("保存", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(activeTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                Button {
                    addTodo()
                } label: {
                    Label("添加", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(activeTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.88), value: isEditing)
    }

    private var todoTextEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: titleBinding)
                .font(.callout)
                .scrollContentBackground(.hidden)
                .frame(height: todoTextEditorHeight)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)

            if activeTitle.isEmpty {
                Text(isEditing ? "待办内容" : "添加新待办...")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
            }
        }
        .background(.quaternary.opacity(0.20))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(.quaternary, lineWidth: 1)
        )
    }

    private func categoryPicker(selection: Binding<UUID?>) -> some View {
        Picker("", selection: selection) {
            Text("无分类").tag(UUID?.none)
            ForEach(store.categories) { cat in
                Label(cat.name, systemImage: cat.iconName).tag(UUID?.some(cat.id))
            }
        }
        .labelsHidden()
    }

    private func priorityPicker(selection: Binding<Priority>) -> some View {
        Picker("", selection: selection) {
            Label("高", systemImage: "exclamationmark.circle.fill").tag(Priority.high)
            Label("中", systemImage: "circle.fill").tag(Priority.medium)
            Label("低", systemImage: "arrow.down.circle.fill").tag(Priority.low)
        }
        .labelsHidden()
    }

    private func formField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            content()
        }
    }

    // MARK: - List

    private var todoList: some View {
        List {
            ForEach(filteredItems) { item in
                todoRow(item)
                    .listRowBackground(
                        editingItemID == item.id && detailMode == .editing
                        ? Color.accentColor.opacity(0.09)
                        : nil
                    )
            }
            .onMove { from, to in
                store.move(from: from, to: to)
            }
            .onDelete { offsets in
                let removedIDs = offsets.map { filteredItems[$0].id }
                for id in removedIDs {
                    store.remove(id: id)
                }
                if let editingItemID, removedIDs.contains(editingItemID) {
                    cancelEditing()
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private func todoRow(_ item: TodoItem) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                store.toggle(item)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(item.isCompleted ? .green : .secondary)
                    .frame(width: completeColumnWidth, height: 24)
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.callout)
                .strikethrough(item.isCompleted)
                .foregroundStyle(item.isCompleted ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            rowPriorityPicker(for: item)
                .frame(width: priorityColumnWidth, alignment: .leading)

            rowCategoryPicker(for: item)
                .frame(width: categoryColumnWidth, alignment: .leading)

            dueDateCell(item)
                .frame(width: dueDateColumnWidth, alignment: .leading)
        }
        .frame(minHeight: 32)
        .padding(.vertical, 1)
        .padding(.horizontal, 8)
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 10))
        .contentShape(Rectangle())
        .onTapGesture {
            selectForEditing(item)
        }
        .contextMenu {
            Button {
                selectForEditing(item)
            } label: {
                Label("选中", systemImage: "cursorarrow.click")
            }

            Divider()

            Button {
                updateRowPriority(item, priority: .high)
            } label: {
                Label("设为高优先级", systemImage: "exclamationmark.circle.fill")
            }
            Button {
                updateRowPriority(item, priority: .medium)
            } label: {
                Label("设为中优先级", systemImage: "circle.fill")
            }
            Button {
                updateRowPriority(item, priority: .low)
            } label: {
                Label("设为低优先级", systemImage: "arrow.down.circle.fill")
            }
        }
    }

    private func rowPriorityPicker(for item: TodoItem) -> some View {
        Picker("", selection: rowPriorityBinding(for: item)) {
            Label("高", systemImage: "exclamationmark.circle.fill").tag(Priority.high)
            Label("中", systemImage: "circle.fill").tag(Priority.medium)
            Label("低", systemImage: "arrow.down.circle.fill").tag(Priority.low)
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
    }

    private func rowCategoryPicker(for item: TodoItem) -> some View {
        Picker("", selection: rowCategoryBinding(for: item)) {
            Text("未分类").tag(UUID?.none)
            ForEach(store.categories) { cat in
                Label(cat.name, systemImage: cat.iconName).tag(UUID?.some(cat.id))
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
    }

    private func dueDateCell(_ item: TodoItem) -> some View {
        Group {
            if let label = item.dueDateLabel {
                HStack(spacing: 5) {
                    Image(systemName: item.isOverdue ? "exclamationmark.triangle.fill" : "calendar")
                    Text(label)
                        .lineLimit(1)
                        .monospacedDigit()
                }
                .foregroundStyle(item.isOverdue ? .red : .secondary)
            } else {
                Text("-")
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.caption)
    }

    private func rowPriorityBinding(for item: TodoItem) -> Binding<Priority> {
        Binding(
            get: {
                store.items.first { $0.id == item.id }?.priority ?? item.priority
            },
            set: { priority in
                updateRowPriority(item, priority: priority)
            }
        )
    }

    private func rowCategoryBinding(for item: TodoItem) -> Binding<UUID?> {
        Binding(
            get: {
                guard let current = store.items.first(where: { $0.id == item.id }) else {
                    return item.categoryID
                }
                return current.categoryID
            },
            set: { categoryID in
                updateRowCategory(item, categoryID: categoryID)
            }
        )
    }

    private func updateRowPriority(_ item: TodoItem, priority: Priority) {
        selectForEditing(item)
        store.updatePriority(id: item.id, priority: priority)
        if editingItemID == item.id {
            editPriority = priority
        }
    }

    private func updateRowCategory(_ item: TodoItem, categoryID: UUID?) {
        selectForEditing(item)
        store.updateCategory(id: item.id, categoryID: categoryID)
        if editingItemID == item.id {
            editCategoryID = categoryID
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var isEditing: Bool {
        detailMode == .editing && editingItemID != nil
    }

    private var isDetailVisible: Bool {
        detailMode != .hidden
    }

    private var detailTitle: String {
        isEditing ? "编辑待办" : "添加待办"
    }

    private var activeTitle: String {
        isEditing ? editTodoText : newTodoText
    }

    private var activeHasDueDate: Bool {
        isEditing ? editHasDueDate : hasDueDate
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { isEditing ? editTodoText : newTodoText },
            set: { value in
                if isEditing {
                    editTodoText = value
                } else {
                    newTodoText = value
                }
            }
        )
    }

    private var categoryBinding: Binding<UUID?> {
        Binding(
            get: { isEditing ? editCategoryID : selectedCategoryID },
            set: { value in
                if isEditing {
                    editCategoryID = value
                } else {
                    selectedCategoryID = value
                }
            }
        )
    }

    private var priorityBinding: Binding<Priority> {
        Binding(
            get: { isEditing ? editPriority : selectedPriority },
            set: { value in
                if isEditing {
                    editPriority = value
                } else {
                    selectedPriority = value
                }
            }
        )
    }

    private var hasDueDateBinding: Binding<Bool> {
        Binding(
            get: { isEditing ? editHasDueDate : hasDueDate },
            set: { value in
                if isEditing {
                    editHasDueDate = value
                } else {
                    hasDueDate = value
                }
            }
        )
    }

    private var dueDateBinding: Binding<Date> {
        Binding(
            get: { isEditing ? editDueDate : dueDate },
            set: { value in
                if isEditing {
                    editDueDate = value
                } else {
                    dueDate = value
                }
            }
        )
    }

    private var filteredItems: [TodoItem] {
        store.items.filter { item in
            if let filterID = filterCategoryID {
                if filterID == uncategorizedFilterID {
                    return item.categoryID == nil
                }
                return item.categoryID == filterID
            }
            return true
        }
    }

    private func submitForm() {
        if isEditing {
            saveTodo()
        } else {
            addTodo()
        }
    }

    private func addTodo() {
        if commitNewTodoDraft() {
            detailMode = .hidden
        }
    }

    private func saveTodo() {
        commitEditingDraft(clearSelection: true)
    }

    @discardableResult
    private func commitActiveDraft() -> Bool {
        switch detailMode {
        case .editing:
            return commitEditingDraft(clearSelection: false)
        case .adding:
            return commitNewTodoDraft()
        case .hidden:
            return false
        }
    }

    @discardableResult
    private func commitNewTodoDraft() -> Bool {
        let title = newTodoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        store.add(title: title, categoryID: selectedCategoryID, dueDate: hasDueDate ? dueDate : nil, priority: selectedPriority)
        newTodoText = ""
        return true
    }

    @discardableResult
    private func commitEditingDraft(clearSelection: Bool) -> Bool {
        guard let editingItemID else { return false }
        let title = editTodoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        store.update(
            id: editingItemID,
            title: title,
            categoryID: editCategoryID,
            dueDate: editHasDueDate ? editDueDate : nil,
            priority: editPriority
        )
        if clearSelection {
            cancelEditing()
        }
        return true
    }

    private func startAddingTodo() {
        commitActiveDraft()
        cancelEditingDraft()
        detailMode = .adding
    }

    private func selectForEditing(_ item: TodoItem) {
        guard editingItemID != item.id || detailMode != .editing else { return }
        commitActiveDraft()
        guard let current = store.items.first(where: { $0.id == item.id }) else { return }
        loadEditingDraft(current)
    }

    private func archiveCompletedTodos() {
        let editingID = editingItemID
        commitActiveDraft()
        store.clearCompleted()

        if let editingID, store.items.contains(where: { $0.id == editingID }) == false {
            cancelEditing()
        }
    }

    private func loadEditingDraft(_ item: TodoItem) {
        detailMode = .editing
        editingItemID = item.id
        editTodoText = item.title
        editCategoryID = item.categoryID
        editPriority = item.priority
        editHasDueDate = item.dueDate != nil
        editDueDate = item.dueDate ?? Date().addingTimeInterval(3600)
    }

    private func cancelEditing() {
        detailMode = .hidden
        cancelEditingDraft()
    }

    private func cancelDetail() {
        if isEditing {
            cancelEditing()
        } else {
            resetNewTodoDraft()
            detailMode = .hidden
        }
    }

    private func cancelEditingDraft() {
        editingItemID = nil
        editTodoText = ""
        editCategoryID = nil
        editPriority = .medium
        editHasDueDate = false
        editDueDate = Date().addingTimeInterval(3600)
    }

    private func resetNewTodoDraft() {
        newTodoText = ""
        selectedCategoryID = nil
        selectedPriority = .medium
        hasDueDate = false
        dueDate = Date().addingTimeInterval(3600)
    }
}
