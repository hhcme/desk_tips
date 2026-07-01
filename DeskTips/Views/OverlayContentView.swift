import SwiftUI
import AppKit
import DeskTipsCore

/// Floating overlay content — compact grouped todo list.
struct OverlayContentView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var settingsStore: SettingsStore

    @ViewBuilder
    var body: some View {
        let settings = settingsStore.settings
        let cornerRadius: CGFloat = 14
        switch settings.displayMode {
        case .glass:
            let intensity = min(max(settings.glassIntensity, 0), 1)
            GlassEffectContainer(
                cornerRadius: cornerRadius,
                tintOpacity: intensity * 0.06
            ) {
                framedContent
            }
        case .frosted, .transparent:
            framedContent
                .background { overlayBackground }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    private var framedContent: some View {
        overlayContent
            .frame(width: 260)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var overlayContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Drag handle — always visible
            dragHandle

            if settingsStore.settings.showsOverlayTitle {
                // Header
                header

                Divider()
                    .padding(.horizontal, 8)
                    .overlay(WindowDragRegion())
            }

            // Todo list grouped by category
            if store.items.isEmpty {
                emptyState
            } else {
                categoryGroupedList
            }
        }
    }

    // MARK: - Drag Handle

    private var dragHandle: some View {
        ZStack {
            Capsule()
                .fill(.secondary.opacity(0.35))
                .frame(width: 36, height: 4)

            WindowDragRegion()
        }
            .frame(height: 20)
            .padding(.horizontal, 8)
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text(overlayTitle)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .overlay(WindowDragRegion())
    }

    // MARK: - Category Grouped List

    private var categoryGroupedList: some View {
        VStack(spacing: 0) {
            ForEach(groupedItems, id: \.category?.id) { group in
                // Category header
                categoryHeader(group.category)

                // Items in this category
                ForEach(group.items) { item in
                    todoRow(item)
                }

                Divider()
                    .padding(.horizontal, 12)
                    .overlay(WindowDragRegion())
            }
        }
        .padding(.vertical, 4)
    }

    private func categoryHeader(_ category: DeskTipsCore.Category?) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: category?.color ?? "#888888"))
                .frame(width: 8, height: 8)
            Text(category?.name ?? "其他")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .overlay(WindowDragRegion())
    }

    // MARK: - Todo Row

    private func todoRow(_ item: TodoItem) -> some View {
        HStack(spacing: 0) {
            // Checkbox
            Button {
                store.toggle(item)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(item.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 12)
            .padding(.trailing, 6)
            .padding(.vertical, 4)

            HStack(spacing: 6) {
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 12)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .overlay(WindowDragRegion())
        }
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
        .overlay(WindowDragRegion())
    }

    // MARK: - Background

    @ViewBuilder
    private var overlayBackground: some View {
        let settings = settingsStore.settings
        let cornerRadius: CGFloat = 14
        switch settings.displayMode {
        case .glass:
            Color.clear
        case .frosted:
            let intensity = min(max(settings.glassIntensity, 0), 1)
            ZStack {
                FrostedBlurBackground(cornerRadius: cornerRadius)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.08 + intensity * 0.24))
            }
        case .transparent:
            let transparency = min(max(settings.transparentOpacity, 0), 1)
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(0.50 - transparency * 0.42))
        }
    }

    // MARK: - Helpers

    /// Group items by category, sorted by category sortOrder.
    private var groupedItems: [(category: DeskTipsCore.Category?, items: [TodoItem])] {
        let sorted = store.categories.sorted { $0.sortOrder < $1.sortOrder }
        var result: [(category: DeskTipsCore.Category?, items: [TodoItem])] = []

        for cat in sorted {
            let catItems = overlaySortedItems(store.items.filter { $0.categoryID == cat.id })
            if !catItems.isEmpty {
                result.append((category: cat, items: catItems))
            }
        }

        let uncategorized = overlaySortedItems(store.items.filter { $0.categoryID == nil })
        if !uncategorized.isEmpty {
            result.append((category: nil, items: uncategorized))
        }

        return result
    }

    private var overlayTitle: String {
        settingsStore.settings.overlayTitle.isEmpty ? "DeskTips" : settingsStore.settings.overlayTitle
    }

    private func overlaySortedItems(_ items: [TodoItem]) -> [TodoItem] {
        items.enumerated().sorted { lhs, rhs in
            let left = lhs.element
            let right = rhs.element

            if left.isCompleted != right.isCompleted {
                return !left.isCompleted && right.isCompleted
            }

            if left.isCompleted, right.isCompleted {
                let leftCompletedAt = left.completedAt ?? .distantPast
                let rightCompletedAt = right.completedAt ?? .distantPast
                if leftCompletedAt != rightCompletedAt {
                    return leftCompletedAt < rightCompletedAt
                }
            }

            return lhs.offset < rhs.offset
        }
        .map(\.element)
    }

    private func priorityColor(_ priority: Priority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
}

// MARK: - Frosted Blur Background

private struct FrostedBlurBackground: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> BlurView {
        let view = BlurView()
        configure(view)
        return view
    }

    func updateNSView(_ nsView: BlurView, context: Context) {
        configure(nsView)
    }

    private func configure(_ view: BlurView) {
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true
    }

    final class BlurView: NSVisualEffectView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

// MARK: - Glass Container

private struct GlassEffectContainer<Content: View>: NSViewRepresentable {
    let cornerRadius: CGFloat
    let tintOpacity: Double
    let content: Content

    init(
        cornerRadius: CGFloat,
        tintOpacity: Double,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.tintOpacity = tintOpacity
        self.content = content()
    }

    func makeNSView(context: Context) -> GlassContainerView<Content> {
        let view = GlassContainerView(rootView: content)
        configure(view)
        return view
    }

    func updateNSView(_ nsView: GlassContainerView<Content>, context: Context) {
        nsView.rootView = content
        configure(nsView)
    }

    private func configure(_ view: GlassContainerView<Content>) {
        view.style = .clear
        view.cornerRadius = cornerRadius
        view.tintColor = tintOpacity > 0 ? NSColor.white.withAlphaComponent(tintOpacity) : nil
    }

    final class GlassContainerView<HostedContent: View>: NSGlassEffectView {
        private let hostingView: NSHostingView<HostedContent>

        var rootView: HostedContent {
            get { hostingView.rootView }
            set {
                hostingView.rootView = newValue
                invalidateIntrinsicContentSize()
            }
        }

        init(rootView: HostedContent) {
            hostingView = NSHostingView(rootView: rootView)
            super.init(frame: .zero)

            hostingView.translatesAutoresizingMaskIntoConstraints = false
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = NSColor.clear.cgColor

            contentView = hostingView

            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override var intrinsicContentSize: NSSize {
            hostingView.intrinsicContentSize
        }

        override var fittingSize: NSSize {
            hostingView.fittingSize
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

// MARK: - AppKit Window Drag Region

private struct WindowDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> DragRegionView { DragRegionView() }
    func updateNSView(_ nsView: DragRegionView, context: Context) {}

    final class DragRegionView: NSView {
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
        }

        required init?(coder: NSCoder) { fatalError() }

        override var acceptsFirstResponder: Bool { false }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func resetCursorRects() {
            super.resetCursorRects()
            addCursorRect(bounds, cursor: .openHand)
        }

        override func mouseDown(with event: NSEvent) {
            NSCursor.closedHand.push()
            window?.performDrag(with: event)
            NSCursor.closedHand.pop()
        }
    }
}
