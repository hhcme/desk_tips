import SwiftUI
import DeskTipsCore

/// Settings popover content shown from the menu bar icon.
struct SettingsView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var settingsStore: SettingsStore
    let overlayController: OverlayWindowController
    var onOpenMainWindow: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            controls
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            footer
        }
        .frame(width: 320, height: 250)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "checklist.checked")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.tint)

            Text("DeskTips")
                .font(.system(size: 17, weight: .semibold))

            Spacer()

            Text("\(store.items.count) 待办")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.6))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label("显示悬浮窗", systemImage: "rectangle.on.rectangle")
                    .font(.callout.weight(.semibold))

                Spacer()

                Toggle("", isOn: Binding(
                    get: { settingsStore.settings.isVisible },
                    set: { _ in settingsStore.toggleVisibility() }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("模式")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("", selection: Binding(
                    get: { settingsStore.settings.displayMode },
                    set: { settingsStore.updateDisplayMode($0) }
                )) {
                    Text("玻璃").tag(OverlayDisplayMode.glass)
                    Text("毛玻璃").tag(OverlayDisplayMode.frosted)
                    Text("透明").tag(OverlayDisplayMode.transparent)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
            }

            switch settingsStore.settings.displayMode {
            case .glass:
                intensitySlider(title: "玻璃强度")
            case .frosted:
                intensitySlider(title: "模糊强度")
            case .transparent:
                VStack(alignment: .leading, spacing: 8) {
                    Text("透明度")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Slider(value: Binding(
                            get: { settingsStore.settings.transparentOpacity },
                            set: { settingsStore.updateTransparentOpacity($0) }
                        ), in: 0.3...1.0, step: 0.05)

                        valueBadge(Int(settingsStore.settings.transparentOpacity * 100))
                    }
                }
            }
        }
    }

    private func intensitySlider(title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Slider(value: Binding(
                    get: { settingsStore.settings.glassIntensity },
                    set: { settingsStore.updateGlassIntensity($0) }
                ), in: 0...1, step: 0.05)

                valueBadge(Int(settingsStore.settings.glassIntensity * 100))
            }
        }
    }

    private func valueBadge(_ value: Int) -> some View {
        Text("\(value)%")
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(width: 44)
            .padding(.vertical, 3)
            .background(.quaternary.opacity(0.55))
            .clipShape(Capsule())
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                onOpenMainWindow()
            } label: {
                Label("主窗口", systemImage: "macwindow")
                    .frame(maxWidth: .infinity)
            }

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("退出", systemImage: "power")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
