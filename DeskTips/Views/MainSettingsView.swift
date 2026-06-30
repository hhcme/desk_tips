import SwiftUI
import ServiceManagement
import DeskTipsCore

/// Settings tab for the main window.
struct MainSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    let overlayController: OverlayWindowController

    @State private var launchAtLogin = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Overlay Settings
                overlaySection

                Divider()

                // System
                systemSection

                Divider()

                // Notifications
                notificationSection

                Divider()

                // About
                aboutSection
            }
            .padding(24)
        }
    }

    // MARK: - Overlay Section

    private var overlaySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("悬浮窗", systemImage: "rectangle.on.rectangle")
                .font(.headline)

            Toggle("显示悬浮窗", isOn: Binding(
                get: { settingsStore.settings.isVisible },
                set: { _ in settingsStore.toggleVisibility() }
            ))

            // Mode picker
            HStack {
                Text("显示模式")
                    .frame(width: 80, alignment: .trailing)
                Picker("", selection: Binding(
                    get: { settingsStore.settings.displayMode },
                    set: { settingsStore.updateDisplayMode($0) }
                )) {
                    Label("玻璃", systemImage: "sparkles").tag(OverlayDisplayMode.glass)
                    Label("透明", systemImage: "eye").tag(OverlayDisplayMode.transparent)
                }
                .pickerStyle(.segmented)
            }

            // Mode-specific slider
            if settingsStore.settings.displayMode == .glass {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("玻璃强度")
                            .frame(width: 80, alignment: .trailing)
                        Slider(value: Binding(
                            get: { settingsStore.settings.glassIntensity },
                            set: { settingsStore.updateGlassIntensity($0) }
                        ), in: 0...1, step: 0.05)
                        Text("\(Int(settingsStore.settings.glassIntensity * 100))%")
                            .monospacedDigit()
                            .frame(width: 40)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("不透明度")
                            .frame(width: 80, alignment: .trailing)
                        Slider(value: Binding(
                            get: { settingsStore.settings.transparentOpacity },
                            set: { settingsStore.updateTransparentOpacity($0) }
                        ), in: 0.3...1.0, step: 0.05)
                        Text("\(Int(settingsStore.settings.transparentOpacity * 100))%")
                            .monospacedDigit()
                            .frame(width: 40)
                    }
                }
            }
        }
    }

    // MARK: - System Section

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("系统", systemImage: "gear")
                .font(.headline)

            Toggle("开机自启动", isOn: $launchAtLogin)
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
        VStack(alignment: .leading, spacing: 14) {
            Label("通知提醒", systemImage: "bell")
                .font(.headline)

            HStack {
                Text("默认提醒时间")
                    .frame(width: 100, alignment: .trailing)
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

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("关于", systemImage: "info.circle")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("DeskTips")
                        .font(.title3.weight(.semibold))
                    Spacer()
                }

                Text("桌面悬浮待办工具")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("版本")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }
                .font(.callout)

                HStack {
                    Text("系统")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            }
            .padding(12)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

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
}
