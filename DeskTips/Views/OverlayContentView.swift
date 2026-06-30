import SwiftUI
import AppKit
import DeskTipsCore

/// Floating overlay content — simplified view-only list with lock/edit dual mode.
struct OverlayContentView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var settingsStore: SettingsStore
    let onEditModeChanged: (Bool) -> Void

    @State private var isEditMode = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Drag handle — always visible
            dragHandle

            // Header
            header

            Divider()
                .padding(.horizontal, 8)

            // Todo list grouped by category
            if store.items.isEmpty {
                emptyState
            } else {
                categoryGroupedList
            }

            // Footer: completed/total count
            footer
        }
        .frame(width: 260)
        .fixedSize(horizontal: false, vertical: true)
        .background { overlayBackground }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isEditMode)
        .onChange(of: isEditMode) { _, newValue in
            onEditModeChanged(newValue)
        }
    }

    // MARK: - Drag Handle

    private var dragHandle: some View {
        DragHandleView()
            .frame(height: 20)
            .padding(.horizontal, 8)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Text(settingsStore.settings.overlayTitle)
                .font(.caption.weight(.semibold))

            Spacer()

            let completed = store.items.filter { $0.isCompleted }.count
            let total = store.items.count
            Text("\(completed)/\(total)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            // Lock/Unlock toggle
            Button {
                withAnimation { isEditMode.toggle() }
            } label: {
                Image(systemName: isEditMode ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(.tint))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.top, isEditMode ? 4 : 10)
        .padding(.bottom, 6)
    }

    // MARK: - Category Grouped List

    private var categoryGroupedList: some View {
        VStack(spacing: 0) {
            ForEach(groupedItems, id: \.category?.id) { group in
                // Category header
                categoryHeader(group.category, count: group.items.count)

                // Items in this category
                ForEach(group.items) { item in
                    todoRow(item)
                }

                Divider().padding(.horizontal, 12)
            }
        }
        .padding(.vertical, 4)
    }

    private func categoryHeader(_ category: DeskTipsCore.Category?, count: Int) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: category?.color ?? "#888888"))
                .frame(width: 8, height: 8)
            Text(category?.name ?? "其他")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(count)")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    // MARK: - Todo Row

    private func todoRow(_ item: TodoItem) -> some View {
        HStack(spacing: 6) {
            // Checkbox
            Button {
                store.toggle(item)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(item.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(!isEditMode)

            // Priority dot
            Circle()
                .fill(priorityColor(item.priority))
                .frame(width: 6, height: 6)

            // Title
            Text(item.title)
                .font(.system(size: 13))
                .strikethrough(item.isCompleted)
                .foregroundStyle(item.isOverdue ? .red : (item.isCompleted ? .secondary : .primary))
                .lineLimit(2)

            Spacer()

            // Due date label
            if let label = item.dueDateLabel {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(item.isOverdue ? .red : .secondary)
            }

            // More menu (edit mode)
            if isEditMode {
                Menu {
                    Button {
                        store.toggle(item)
                    } label: {
                        Label(item.isCompleted ? "取消完成" : "标记完成",
                              systemImage: item.isCompleted ? "arrow.uturn.backward" : "checkmark")
                    }
                    Divider()
                    Button(role: .destructive) {
                        store.remove(id: item.id)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            if store.completedCount > 0 && isEditMode {
                Button("清理已完成") {
                    store.clearCompleted()
                }
                .font(.system(size: 10))
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: "tray")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("暂无待办")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Background

    @ViewBuilder
    private var overlayBackground: some View {
        let settings = settingsStore.settings
        switch settings.displayMode {
        case .glass:
            RoundedRectangle(cornerRadius: 14)
                .fill(.thickMaterial)
                .opacity(0.3 + settings.glassIntensity * 0.7)
        case .transparent:
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .opacity(0.2 + settings.transparentOpacity * 0.8)
        }
    }

    // MARK: - Helpers

    /// Group items by category, sorted by category sortOrder.
    private var groupedItems: [(category: DeskTipsCore.Category?, items: [TodoItem])] {
        let sorted = store.categories.sorted { $0.sortOrder < $1.sortOrder }
        var result: [(category: DeskTipsCore.Category?, items: [TodoItem])] = []

        for cat in sorted {
            let catItems = store.items.filter { $0.categoryID == cat.id }
            if !catItems.isEmpty {
                result.append((category: cat, items: catItems))
            }
        }

        let uncategorized = store.items.filter { $0.categoryID == nil }
        if !uncategorized.isEmpty {
            result.append((category: nil, items: uncategorized))
        }

        return result
    }

    private func priorityColor(_ priority: Priority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
}

// MARK: - Color from Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - AppKit Drag Handle

private struct DragHandleView: NSViewRepresentable {
    func makeNSView(context: Context) -> HandleView { HandleView() }
    func updateNSView(_ nsView: HandleView, context: Context) {}

    class HandleView: NSView {
        private var isHovering = false

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.cornerRadius = 6
            setupTracking()
            addDragIndicator()
        }

        required init?(coder: NSCoder) { fatalError() }

        private func setupTracking() {
            addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .mouseMoved], owner: self, userInfo: nil))
        }

        private func addDragIndicator() {
            let indicator = NSView()
            indicator.wantsLayer = true
            indicator.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.35).cgColor
            indicator.layer?.cornerRadius = 2
            indicator.translatesAutoresizingMaskIntoConstraints = false
            addSubview(indicator)
            NSLayoutConstraint.activate([
                indicator.centerXAnchor.constraint(equalTo: centerXAnchor),
                indicator.centerYAnchor.constraint(equalTo: centerYAnchor),
                indicator.widthAnchor.constraint(equalToConstant: 36),
                indicator.heightAnchor.constraint(equalToConstant: 4),
            ])
        }

        override func mouseEntered(with event: NSEvent) {
            isHovering = true
            NSCursor.openHand.push()
            NSAnimationContext.runAnimationGroup { $0.duration = 0.15; self.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor }
        }

        override func mouseExited(with event: NSEvent) {
            isHovering = false
            NSCursor.pop()
            NSAnimationContext.runAnimationGroup { $0.duration = 0.15; self.layer?.backgroundColor = NSColor.clear.cgColor }
        }

        override func mouseDown(with event: NSEvent) {
            NSCursor.closedHand.push()
            window?.performDrag(with: event)
            NSCursor.closedHand.pop()
            if !isHovering { layer?.backgroundColor = NSColor.clear.cgColor }
        }

        override var acceptsFirstResponder: Bool { false }
    }
}
