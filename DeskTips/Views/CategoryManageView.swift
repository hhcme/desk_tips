import SwiftUI
import DeskTipsCore

/// Category management tab in the main window.
struct CategoryManageView: View {
    @ObservedObject var store: TodoStore

    @State private var editingCategoryID: UUID?
    @State private var name = ""
    @State private var selectedColor = "#3B82F6"
    @State private var selectedIcon = "folder.fill"
    @State private var selectedCategoryIDs: Set<UUID> = []
    @State private var pendingDeleteCategoryIDs: Set<UUID> = []
    @State private var showDeleteConfirmation = false
    @State private var detailMode: DetailMode = .hidden

    private let selectionColumnWidth: CGFloat = 26
    private let countColumnWidth: CGFloat = 56
    private let deleteColumnWidth: CGFloat = 26
    private let colors = ["#3B82F6", "#10B981", "#8B5CF6", "#F59E0B", "#EF4444", "#EC4899", "#06B6D4", "#84CC16"]
    private let icons = [
        "folder.fill",
        "briefcase.fill",
        "house.fill",
        "book.fill",
        "heart.fill",
        "star.fill",
        "person.fill",
        "cart.fill",
        "graduationcap.fill",
        "gamecontroller.fill",
        "music.note",
        "camera.fill",
    ]

    private enum DetailMode: Equatable {
        case hidden
        case adding
        case editing
    }

    var body: some View {
        HStack(spacing: 0) {
            listPane
                .frame(minWidth: isDetailVisible ? 620 : 900, maxWidth: .infinity, maxHeight: .infinity)

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
        .alert("删除分类？", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deletePendingCategories()
            }
        } message: {
            Text(deleteConfirmationMessage)
        }
    }

    // MARK: - List Pane

    private var listPane: some View {
        VStack(spacing: 0) {
            listHeader

            Divider()

            categoryTableHeader

            Divider()

            if store.categories.isEmpty {
                emptyState
            } else {
                categoryList
            }
        }
    }

    private var listHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("分类管理")
                    .font(.headline.weight(.semibold))
                Text(categoryCountLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                confirmDeleteCategories(selectedCategoryIDs)
            } label: {
                Label(batchDeleteTitle, systemImage: "trash")
            }
            .controlSize(.small)
            .disabled(selectedCategoryIDs.isEmpty)
            .tint(.red)

            Button {
                startAddingCategory()
            } label: {
                Label("新建分类", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var categoryTableHeader: some View {
        HStack(spacing: 8) {
            selectAllButton
                .frame(width: selectionColumnWidth)
            tableHeaderText("分类")
                .frame(maxWidth: .infinity, alignment: .leading)
            tableHeaderText("待办数")
                .frame(width: countColumnWidth, alignment: .trailing)
            tableHeaderText("")
                .frame(width: deleteColumnWidth)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.12))
    }

    private func tableHeaderText(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private var categoryList: some View {
        List {
            ForEach(store.categories) { cat in
                categoryRow(cat)
                    .listRowBackground(
                        editingCategoryID == cat.id && detailMode == .editing
                        ? Color.accentColor.opacity(0.09)
                        : nil
                    )
            }
            .onDelete { offsets in
                let ids = Set(offsets.map { store.categories[$0].id })
                confirmDeleteCategories(ids)
            }
            .onMove { from, to in
                commitActiveDraft()
                store.moveCategory(from: from, to: to)
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private func categoryRow(_ category: DeskTipsCore.Category) -> some View {
        HStack(spacing: 10) {
            categorySelectionButton(category.id)
                .frame(width: selectionColumnWidth)

            Circle()
                .fill(Color(hex: category.color))
                .frame(width: 10, height: 10)

            Image(systemName: category.iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: category.color))
                .frame(width: 20)

            Text(category.name)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Text("\(store.itemsForCategory(category.id).count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: countColumnWidth, alignment: .trailing)

            Button(role: .destructive) {
                confirmDeleteCategories(Set([category.id]))
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.red.opacity(0.78))
                    .frame(width: deleteColumnWidth, height: 24)
            }
            .buttonStyle(.plain)
            .help("删除分类")
        }
        .frame(minHeight: 32)
        .padding(.vertical, 1)
        .padding(.horizontal, 8)
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
        .contentShape(Rectangle())
        .onTapGesture {
            selectForEditing(category)
        }
        .contextMenu {
            Button {
                selectForEditing(category)
            } label: {
                Label("编辑", systemImage: "cursorarrow.click")
            }

            Button(role: .destructive) {
                confirmDeleteCategories(Set([category.id]))
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private var selectAllButton: some View {
        Button {
            toggleSelectAll()
        } label: {
            Image(systemName: selectAllIconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(selectedCategoryIDs.isEmpty ? Color.secondary : Color.accentColor)
                .frame(width: selectionColumnWidth, height: 22)
        }
        .buttonStyle(.plain)
        .disabled(store.categories.isEmpty)
        .help("选择全部")
    }

    private func categorySelectionButton(_ id: UUID) -> some View {
        let isSelected = selectedCategoryIDs.contains(id)
        return Button {
            toggleCategorySelection(id)
        } label: {
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: selectionColumnWidth, height: 24)
        }
        .buttonStyle(.plain)
        .help(isSelected ? "取消选择" : "选择分类")
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("暂无分类")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Detail Pane

    private var detailPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Text(isEditing ? "编辑分类" : "添加分类")
                    .font(.headline.weight(.semibold))

                Spacer()

                Button {
                    resetForm()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help("关闭")
            }

            ScrollView {
                categoryForm
                    .padding(.top, 18)
                    .padding(.bottom, 12)
            }
            .scrollIndicators(.automatic)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            categoryActionBar
        }
        .padding(18)
        .background(.quaternary.opacity(0.18))
    }

    private var categoryForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            formField("名称") {
                TextField("分类名称", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            formField("颜色") {
                colorGrid
            }

            formField("图标") {
                iconGrid
            }
        }
    }

    private var colorGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 8), count: 6), alignment: .leading, spacing: 8) {
            ForEach(colors, id: \.self) { hex in
                colorButton(hex)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var iconGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 8), count: 6), alignment: .leading, spacing: 8) {
            ForEach(icons, id: \.self) { icon in
                iconButton(icon)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func colorButton(_ hex: String) -> some View {
        let isSelected = selectedColor == hex
        return Button {
            selectedColor = hex
        } label: {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .strokeBorder(isSelected ? Color.primary : Color.clear, lineWidth: 2)
                )
                .padding(2)
        }
        .buttonStyle(.plain)
        .help(hex)
    }

    private func iconButton(_ icon: String) -> some View {
        let isSelected = selectedIcon == icon
        return Button {
            selectedIcon = icon
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Color(hex: selectedColor))
                .frame(width: 30, height: 30)
                .background(isSelected ? Color(hex: selectedColor) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isSelected ? Color.clear : Color.secondary.opacity(0.22), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(icon)
    }

    private func formField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private var categoryActionBar: some View {
        VStack(spacing: 12) {
            Divider()

            if isEditing {
                HStack(spacing: 10) {
                    Button("取消") {
                        resetForm()
                    }

                    Button {
                        saveCategory()
                    } label: {
                        Label("保存", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedName.isEmpty)
                }
            } else {
                Button {
                    addCategory()
                } label: {
                    Label("添加", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(trimmedName.isEmpty)
            }
        }
    }

    // MARK: - Helpers

    private var isEditing: Bool {
        detailMode == .editing && editingCategoryID != nil
    }

    private var isDetailVisible: Bool {
        detailMode != .hidden
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var categoryCountLabel: String {
        if selectedCategoryIDs.isEmpty {
            return "\(store.categories.count) 个分类"
        }
        return "\(store.categories.count) 个分类，已选择 \(selectedCategoryIDs.count) 个"
    }

    private var batchDeleteTitle: String {
        selectedCategoryIDs.isEmpty ? "批量删除" : "删除 \(selectedCategoryIDs.count) 个"
    }

    private var currentCategoryIDs: Set<UUID> {
        Set(store.categories.map(\.id))
    }

    private var selectAllIconName: String {
        if selectedCategoryIDs.isEmpty {
            return "square"
        }
        return selectedCategoryIDs.isSuperset(of: currentCategoryIDs) ? "checkmark.square.fill" : "minus.square.fill"
    }

    private var deleteConfirmationMessage: String {
        let validIDs = pendingDeleteCategoryIDs.intersection(currentCategoryIDs)
        let fallback = "所选分类会被删除，相关待办会自动变为无分类。"
        guard !validIDs.isEmpty else {
            return fallback
        }
        let categories = store.categories.filter { validIDs.contains($0.id) }
        let linkedTodoCount = store.items.filter { item in
            guard let categoryID = item.categoryID else { return false }
            return validIDs.contains(categoryID)
        }.count

        if categories.count == 1, let category = categories.first {
            if linkedTodoCount == 0 {
                return "“\(category.name)”会被删除。"
            }
            return "“\(category.name)”会被删除，\(linkedTodoCount) 个相关待办会自动变为无分类。"
        }

        if linkedTodoCount == 0 {
            return "\(categories.count) 个分类会被删除。"
        }
        return "\(categories.count) 个分类会被删除，\(linkedTodoCount) 个相关待办会自动变为无分类。"
    }

    private func toggleCategorySelection(_ id: UUID) {
        if selectedCategoryIDs.contains(id) {
            selectedCategoryIDs.remove(id)
        } else {
            selectedCategoryIDs.insert(id)
        }
    }

    private func toggleSelectAll() {
        let ids = currentCategoryIDs
        if selectedCategoryIDs.isSuperset(of: ids), !ids.isEmpty {
            selectedCategoryIDs.removeAll()
        } else {
            selectedCategoryIDs = ids
        }
    }

    private func confirmDeleteCategories(_ ids: Set<UUID>) {
        let validIDs = ids.intersection(currentCategoryIDs)
        guard !validIDs.isEmpty else { return }

        if editingCategoryID.map({ validIDs.contains($0) }) != true {
            commitActiveDraft()
        }

        pendingDeleteCategoryIDs = validIDs
        showDeleteConfirmation = true
    }

    private func deletePendingCategories() {
        let validIDs = pendingDeleteCategoryIDs.intersection(currentCategoryIDs)
        guard !validIDs.isEmpty else {
            pendingDeleteCategoryIDs.removeAll()
            return
        }

        store.removeCategories(ids: validIDs)
        selectedCategoryIDs.subtract(validIDs)
        pendingDeleteCategoryIDs.removeAll()

        if editingCategoryID.map({ validIDs.contains($0) }) == true {
            resetForm()
        }
    }

    private func startAddingCategory() {
        commitActiveDraft()
        resetForm()
        detailMode = .adding
    }

    private func selectForEditing(_ category: DeskTipsCore.Category) {
        guard editingCategoryID != category.id || detailMode != .editing else { return }
        commitActiveDraft()
        guard let current = store.categories.first(where: { $0.id == category.id }) else { return }
        loadEditingDraft(current)
    }

    private func loadEditingDraft(_ category: DeskTipsCore.Category) {
        detailMode = .editing
        editingCategoryID = category.id
        name = category.name
        selectedColor = category.color
        selectedIcon = category.iconName
    }

    private func addCategory() {
        if commitNewCategoryDraft() {
            resetForm()
        }
    }

    private func saveCategory() {
        commitEditingDraft(clearSelection: true)
    }

    @discardableResult
    private func commitActiveDraft() -> Bool {
        switch detailMode {
        case .editing:
            return commitEditingDraft(clearSelection: false)
        case .adding:
            return commitNewCategoryDraft()
        case .hidden:
            return false
        }
    }

    @discardableResult
    private func commitNewCategoryDraft() -> Bool {
        guard !trimmedName.isEmpty else { return false }
        store.addCategory(name: trimmedName, color: selectedColor, iconName: selectedIcon)
        return true
    }

    @discardableResult
    private func commitEditingDraft(clearSelection: Bool) -> Bool {
        guard let editingCategoryID else { return false }
        guard !trimmedName.isEmpty else { return false }
        store.updateCategory(id: editingCategoryID, name: trimmedName, color: selectedColor, iconName: selectedIcon)
        if clearSelection {
            resetForm()
        }
        return true
    }

    private func resetForm() {
        detailMode = .hidden
        editingCategoryID = nil
        name = ""
        selectedColor = "#3B82F6"
        selectedIcon = "folder.fill"
    }
}
