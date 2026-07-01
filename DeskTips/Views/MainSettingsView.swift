import SwiftUI
import ServiceManagement
import DeskTipsCore

/// Settings tab for the main window.
struct MainSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    let overlayController: OverlayWindowController

    @State private var launchAtLogin = false
    @State private var selectedSection: SettingsSection = .overlay

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            detailPane
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置")
                .font(.title2.weight(.semibold))
                .padding(.horizontal, 18)
                .padding(.top, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(SettingsSection.allCases) { section in
                        sidebarRow(section)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 18)
            }
        }
        .frame(width: 248)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.quaternary.opacity(0.18))
    }

    private var detailPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Image(systemName: selectedSection.systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    Text(selectedSection.title)
                        .font(.title2.weight(.semibold))
                }

                selectedDetail
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sidebarRow(_ section: SettingsSection) -> some View {
        let isSelected = selectedSection == section

        return Button {
            selectedSection = section
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                        .font(.callout.weight(.semibold))

                    Text(section.subtitle)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.82) : .secondary)
                }

                Spacer()
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var selectedDetail: some View {
        switch selectedSection {
        case .overlay:
            overlaySection
        case .system:
            systemSection
        case .notifications:
            notificationSection
        }
    }

    // MARK: - Overlay Section

    private var overlaySection: some View {
        settingsPanel {
            Label("悬浮窗", systemImage: "rectangle.on.rectangle")
                .font(.headline)

            Divider()

            Toggle("显示悬浮窗", isOn: Binding(
                get: { settingsStore.settings.isVisible },
                set: { _ in settingsStore.toggleVisibility() }
            ))

            formRow("标题") {
                TextField("DeskTips", text: Binding(
                    get: { settingsStore.settings.overlayTitle },
                    set: { settingsStore.updateOverlayTitle($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 280)
            }

            formRow("") {
                Toggle("显示标题", isOn: Binding(
                    get: { settingsStore.settings.showsOverlayTitle },
                    set: { settingsStore.setOverlayTitleVisible($0) }
                ))
                .toggleStyle(.checkbox)
            }

            formRow("显示模式") {
                Picker("", selection: Binding(
                    get: { settingsStore.settings.displayMode },
                    set: { settingsStore.updateDisplayMode($0) }
                )) {
                    Label("玻璃", systemImage: "sparkles").tag(OverlayDisplayMode.glass)
                    Label("毛玻璃", systemImage: "rectangle.on.rectangle").tag(OverlayDisplayMode.frosted)
                    Label("透明", systemImage: "eye").tag(OverlayDisplayMode.transparent)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }

            intensityControl
        }
    }

    // MARK: - System Section

    private var systemSection: some View {
        settingsPanel {
            Label("系统", systemImage: "gear")
                .font(.headline)

            Divider()

            Toggle("开机自启动", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                .onChange(of: launchAtLogin) { _, newValue in
                    setLaunchAtLogin(newValue)
                }
        }
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    // MARK: - Notification Section

    private let reminderOptions: [(String, TimeInterval)] = [
        ("不提醒", 0),
        ("5 分钟前", 300),
        ("15 分钟前", 900),
        ("30 分钟前", 1800),
        ("1 小时前", 3600),
        ("1 天前", 86400),
    ]

    private var notificationSection: some View {
        settingsPanel {
            Label("通知提醒", systemImage: "bell")
                .font(.headline)

            Divider()

            formRow("默认提醒") {
                Picker("", selection: Binding(
                    get: { settingsStore.settings.defaultReminderOffset },
                    set: { settingsStore.updateDefaultReminderOffset($0) }
                )) {
                    ForEach(reminderOptions, id: \.1) { option in
                        Text(option.0).tag(option.1)
                    }
                }
                .frame(width: 140)
            }
        }
    }

    // MARK: - Helpers

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Revert on failure
            launchAtLogin = !enabled
            NSLog("[DeskTips] Launch at login error: %@", error.localizedDescription)
        }
    }

    @ViewBuilder
    private var intensityControl: some View {
        switch settingsStore.settings.displayMode {
        case .glass:
            formRow("玻璃强度") {
                sliderRow(
                    value: settingsStore.settings.glassIntensity,
                    range: 0...1,
                    binding: Binding(
                        get: { settingsStore.settings.glassIntensity },
                        set: { settingsStore.updateGlassIntensity($0) }
                    )
                )
            }
        case .frosted:
            formRow("模糊强度") {
                sliderRow(
                    value: settingsStore.settings.glassIntensity,
                    range: 0...1,
                    binding: Binding(
                        get: { settingsStore.settings.glassIntensity },
                        set: { settingsStore.updateGlassIntensity($0) }
                    )
                )
            }
        case .transparent:
            formRow("透明度") {
                sliderRow(
                    value: settingsStore.settings.transparentOpacity,
                    range: 0.3...1,
                    binding: Binding(
                        get: { settingsStore.settings.transparentOpacity },
                        set: { settingsStore.updateTransparentOpacity($0) }
                    )
                )
            }
        }
    }

    private func settingsPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14, content: content)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(.quaternary.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 82, alignment: .trailing)

            content()

            Spacer(minLength: 0)
        }
    }

    private func sliderRow(
        value: Double,
        range: ClosedRange<Double>,
        binding: Binding<Double>
    ) -> some View {
        HStack(spacing: 10) {
            Slider(value: binding, in: range, step: 0.05)
                .frame(maxWidth: 360)

            Text("\(Int(value * 100))%")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case overlay
    case system
    case notifications

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overlay:
            return "桌面悬浮"
        case .system:
            return "系统"
        case .notifications:
            return "通知提醒"
        }
    }

    var subtitle: String {
        switch self {
        case .overlay:
            return "显示、标题与外观"
        case .system:
            return "开机自启动"
        case .notifications:
            return "默认提醒时间"
        }
    }

    var systemImage: String {
        switch self {
        case .overlay:
            return "rectangle.on.rectangle"
        case .system:
            return "gearshape"
        case .notifications:
            return "bell"
        }
    }
}
