import SwiftUI
import AppKit
import DeskTipsCore

/// Floating overlay content with lock/edit dual mode.
struct OverlayContentView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var settingsStore: SettingsStore
    let onEditModeChanged: (Bool) -> Void

    @State private var isEditMode = false
    @State private var newTodoText = ""
    @State private var titleText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Drag handle (edit mode only)
            // Drag handle — always visible
            dragHandle

            // Header with title
            header

            Divider()
                .padding(.horizontal, 8)

            // Add input (edit mode only, animated)
            if isEditMode {
                addBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Todo items
            if store.items.isEmpty && !isEditMode {
                emptyState
            } else {
                todoItems
            }
        }
        .frame(width: 260)
        .fixedSize(horizontal: false, vertical: true)
        .background { overlayBackground }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isEditMode)
        .onChange(of: isEditMode) { _, newValue in
            onEditModeChanged(newValue)
            if newValue {
                titleText = settingsStore.settings.overlayTitle
            }
        }
    }

    // MARK: - Drag Handle (edit mode, AppKit native drag)

    private var dragHandle: some View {
        DragHandleView()
            .frame(height: 20)
            .padding(.horizontal, 8)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            // Edit mode: title is editable
            if isEditMode {
                TextField("", text: $titleText)
                    .textFieldStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: 120)
                    .onSubmit {
                        settingsStore.updateOverlayTitle(titleText)
                    }
            } else {
                Text(settingsStore.settings.overlayTitle)
                    .font(.caption.weight(.semibold))
            }

            Spacer()

            // Display: completed/total
            let completed = store.items.filter { $0.isCompleted }.count
            let total = store.items.count
            Text("\(completed)/\(total)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            // Edit/Lock toggle button
            Button {
                withAnimation {
                    if isEditMode {
                        let trimmed = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty && trimmed != settingsStore.settings.overlayTitle {
                            settingsStore.updateOverlayTitle(titleText)
                        }
                    }
                    isEditMode.toggle()
                }
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

    // MARK: - Add Bar (edit mode)

    private var addBar: some View {
        HStack(spacing: 6) {
            TextField("添加待办…", text: $newTodoText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .onSubmit {
                    addTodo()
                }

            if !newTodoText.isEmpty {
                Button {
                    newTodoText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - Todo Items

    private var todoItems: some View {
        VStack(spacing: 0) {
            ForEach(store.items) { item in
                todoRow(item)
                if item.id != store.items.last?.id {
                    Divider()
                        .padding(.horizontal, 12)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func todoRow(_ item: TodoItem) -> some View {
        HStack(spacing: 8) {
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

            // Title
            Text(item.title)
                .font(.system(size: 13))
                .strikethrough(item.isCompleted)
                .foregroundStyle(item.isCompleted ? .secondary : .primary)
                .lineLimit(2)

            Spacer()

            // More menu (edit mode only)
            if isEditMode {
                Menu {
                    Button {
                        store.toggle(item)
                    } label: {
                        Label(
                            item.isCompleted ? "取消完成" : "标记完成",
                            systemImage: item.isCompleted ? "arrow.uturn.backward" : "checkmark"
                        )
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
        .padding(.vertical, 5)
        .contentShape(Rectangle())
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

    // MARK: - Actions

    private func addTodo() {
        store.add(title: newTodoText)
        newTodoText = ""
    }

    /// Find the overlay NSPanel by identifier.
    private func findOverlayWindow() -> NSPanel? {
        NSApp.windows.first(where: { $0.identifier?.rawValue == "DeskTipsOverlay" }) as? NSPanel
    }
}

// MARK: - AppKit Drag Handle (full-width, native performDrag + cursor + highlight)

private struct DragHandleView: NSViewRepresentable {
    func makeNSView(context: Context) -> HandleView {
        let view = HandleView()
        return view
    }

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

        override var isFlipped: Bool { true }

        private func setupTracking() {
            let trackingArea = NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .mouseMoved],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(trackingArea)
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

        // Hover highlight
        override func mouseEntered(with event: NSEvent) {
            isHovering = true
            NSCursor.openHand.push()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                self.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
            }
        }

        override func mouseExited(with event: NSEvent) {
            isHovering = false
            NSCursor.pop()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                self.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }

        // Native drag
        override func mouseDown(with event: NSEvent) {
            NSCursor.closedHand.push()
            window?.performDrag(with: event)
            NSCursor.closedHand.pop()
            if !isHovering {
                // Reset background if mouse ended outside
                layer?.backgroundColor = NSColor.clear.cgColor
            }
        }

        override var acceptsFirstResponder: Bool { false }
    }
}
