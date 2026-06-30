import SwiftUI
import DeskTipsCore

/// Category management tab in the main window.
struct CategoryManageView: View {
    @ObservedObject var store: TodoStore
    @State private var editingCategory: DeskTipsCore.Category?
    @State private var showAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("分类管理")
                    .font(.headline)
                Spacer()
                Button {
                    editingCategory = nil
                    showAddSheet = true
                } label: {
                    Label("添加", systemImage: "plus")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            List {
                ForEach(store.categories) { cat in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: cat.color))
                            .frame(width: 14, height: 14)
                        Image(systemName: cat.iconName)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(cat.name)
                        Spacer()
                        let count = store.itemsForCategory(cat.id).count
                        Text("\(count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingCategory = cat
                        showAddSheet = true
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        store.removeCategory(id: store.categories[index].id)
                    }
                }
                .onMove { from, to in
                    store.moveCategory(from: from, to: to)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        .sheet(isPresented: $showAddSheet) {
            CategoryEditSheet(
                store: store,
                category: editingCategory,
                isPresented: $showAddSheet
            )
        }
    }
}

// MARK: - Category Edit Sheet

private struct CategoryEditSheet: View {
    let store: TodoStore
    let category: DeskTipsCore.Category?
    @Binding var isPresented: Bool

    @State private var name = ""
    @State private var selectedColor = "#3B82F6"
    @State private var selectedIcon = "folder.fill"

    private let colors = ["#3B82F6", "#10B981", "#8B5CF6", "#F59E0B", "#EF4444", "#EC4899", "#06B6D4", "#84CC16"]
    private let icons = ["folder.fill", "briefcase.fill", "house.fill", "book.fill", "heart.fill", "star.fill", "person.fill", "cart.fill", "graduationcap.fill", "gamecontroller.fill", "music.note", "camera.fill"]

    var body: some View {
        VStack(spacing: 16) {
            Text(category == nil ? "添加分类" : "编辑分类")
                .font(.headline)

            TextField("分类名称", text: $name)
                .textFieldStyle(.roundedBorder)

            // Color picker
            HStack(spacing: 8) {
                Text("颜色")
                Spacer()
                ForEach(colors, id: \.self) { hex in
                    colorButton(hex)
                }
            }

            // Icon picker
            HStack {
                Text("图标")
                Spacer()
                ForEach(icons, id: \.self) { icon in
                    Image(systemName: icon)
                        .font(.title3)
                        .opacity(selectedIcon == icon ? 1.0 : 0.4)
                        .onTapGesture { selectedIcon = icon }
                }
            }

            HStack {
                Button("取消") { isPresented = false }
                Spacer()
                Button("保存") {
                    if let cat = category {
                        store.updateCategory(id: cat.id, name: name, color: selectedColor, iconName: selectedIcon)
                    } else {
                        store.addCategory(name: name, color: selectedColor, iconName: selectedIcon)
                    }
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear {
            if let cat = category {
                name = cat.name
                selectedColor = cat.color
                selectedIcon = cat.iconName
            }
        }
    }

    @ViewBuilder
    private func colorButton(_ hex: String) -> some View {
        let isSelected = selectedColor == hex
        let c = Color(hex: hex)
        Circle()
            .fill(c)
            .frame(width: 24, height: 24)
            .overlay(Circle().strokeBorder(Color.primary, lineWidth: isSelected ? 2 : 0))
            .onTapGesture { selectedColor = hex }
    }
}
