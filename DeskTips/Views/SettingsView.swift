import SwiftUI
import DeskTipsCore

/// Settings popover content — shown from the menu bar icon.
/// Will be replaced by QuickPopoverView in Step 4.
struct SettingsView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var settingsStore: SettingsStore
    let overlayController: OverlayWindowController
    var onOpenMainWindow: () -> Void = {}

    @State private var newTodoText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Controls
            controls
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            // Todo list
            todoList

            Divider()

            // Add todo
            addTodoBar
                .padding(12)

            // Footer
            footer
        }
        .frame(width: 300, height: 440)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "checklist.checked")
                .font(.title2)
                .foregroundStyle(.tint)
            Text("DeskTips")
                .font(.headline)
            Spacer()
            Text("\(store.items.count) 待办")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 10) {
            HStack {
                Toggle("显示悬浮窗", isOn: Binding(
                    get: { settingsStore.settings.isVisible },
                    set: { _ in settingsStore.toggleVisibility() }
                ))
            }

            HStack {
                Text("模式")
                    .font(.callout)
                Spacer()
                Picker("", selection: Binding(
                    get: { settingsStore.settings.displayMode },
                    set: { settingsStore.updateDisplayMode($0) }
                )) {
                    Text("玻璃").tag(OverlayDisplayMode.glass)
                    Text("透明").tag(OverlayDisplayMode.transparent)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }

            if settingsStore.settings.displayMode == .glass {
                HStack {
                    Text("玻璃强度")
                        .font(.callout)
                    Slider(value: Binding(
                        get: { settingsStore.settings.glassIntensity },
                        set: { settingsStore.updateGlassIntensity($0) }
                    ), in: 0...1, step: 0.05)
                    Text("\(Int(settingsStore.settings.glassIntensity * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 36)
                }
            } else {
                HStack {
                    Text("不透明度")
                        .font(.callout)
                    Slider(value: Binding(
                        get: { settingsStore.settings.transparentOpacity },
                        set: { settingsStore.updateTransparentOpacity($0) }
                    ), in: 0.3...1.0, step: 0.05)
                    Text("\(Int(settingsStore.settings.transparentOpacity * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: 36)
                }
            }
        }
    }

    // MARK: - Todo List

    private var todoList: some View {
        List {
            ForEach(store.items) { item in
                HStack(spacing: 8) {
                    Button {
                        store.toggle(item)
                    } label: {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isCompleted ? .green : .secondary)
                    }
                    .buttonStyle(.plain)

                    Text(item.title)
                        .strikethrough(item.isCompleted)
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                        .font(.callout)

                    Spacer()

                    Button {
                        store.remove(id: item.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary.opacity(0.5))
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Add Todo Bar

    private var addTodoBar: some View {
        HStack(spacing: 8) {
            TextField("添加待办…", text: $newTodoText)
                .textFieldStyle(.plain)
                .font(.callout)
                .onSubmit {
                    addTodo()
                }

            Button {
                addTodo()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.tint)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(newTodoText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("打开主窗口") {
                onOpenMainWindow()
            }
            .font(.caption)

            Spacer()

            Button("退出") {
                NSApp.terminate(nil)
            }
            .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    // MARK: - Actions

    private func addTodo() {
        store.add(title: newTodoText)
        newTodoText = ""
    }
}
