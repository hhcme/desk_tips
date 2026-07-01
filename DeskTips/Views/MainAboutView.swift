import AppKit
import SwiftUI

/// About tab for version, repository, and update status.
struct MainAboutView: View {
    @StateObject private var updateManager = UpdateManager.shared
    @State private var selectedSection: AboutSection = .updates

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            detailPane
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("关于")
                .font(.title2.weight(.semibold))
                .padding(.horizontal, 18)
                .padding(.top, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(AboutSection.allCases) { section in
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
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: selectedSection.systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    Text(selectedSection.title)
                        .font(.title2.weight(.semibold))

                    if selectedSection == .updates, updateManager.hasAvailableUpdate {
                        updateDot
                            .offset(y: -1)
                    }
                }

                selectedDetail
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sidebarRow(_ section: AboutSection) -> some View {
        let isSelected = selectedSection == section
        let showsDot = section == .updates && updateManager.hasAvailableUpdate

        return Button {
            selectedSection = section
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(section.title)
                            .font(.callout.weight(.semibold))

                        if showsDot {
                            updateDot
                        }
                    }

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
        case .appInfo:
            appInfoSection
        case .updates:
            updateSection
        }
    }

    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DeskTips")
                        .font(.title3.weight(.semibold))

                    Text("桌面悬浮待办工具")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    NSWorkspace.shared.open(updateManager.repositoryURL)
                } label: {
                    Label("GitHub 仓库", systemImage: "arrow.up.right.square")
                }
            }

            Divider()

            infoRow(title: "版本", value: updateManager.currentDisplayVersion)
            infoRow(title: "系统", value: "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
            infoRow(title: "Bundle ID", value: updateManager.bundleIdentifier)
            infoRow(title: "更新源", value: "GitHub Releases")
        }
        .padding(16)
        .background(.quaternary.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var updateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                updateStatus

                Spacer(minLength: 12)

                updateActions
            }

            if let update = updateManager.availableUpdate {
                releaseNotes(for: update)
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var updateActions: some View {
        HStack(spacing: 10) {
            Button {
                updateManager.checkForUpdates()
            } label: {
                Label(recheckTitle, systemImage: "arrow.triangle.2.circlepath")
                    .frame(minWidth: 110)
            }
            .disabled(updateManager.state.isBusy || !updateManager.canCheckForUpdates)

            if showsInstallButton {
                Button {
                    updateManager.installAvailableUpdate()
                } label: {
                    Label(updateButtonTitle, systemImage: "square.and.arrow.down")
                        .frame(minWidth: 132)
                }
                .buttonStyle(.borderedProminent)
                .disabled(updateManager.state.isBusy)
            } else if updateManager.state.isBusy, updateManager.availableUpdate != nil {
                Button {
                } label: {
                    Label(updateButtonTitle, systemImage: "square.and.arrow.down")
                        .frame(minWidth: 132)
                }
                .buttonStyle(.borderedProminent)
                .disabled(true)
            }
        }
        .controlSize(.small)
    }

    private var updateStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch updateManager.state {
            case .idle:
                Text("启动后会自动检查更新。")
                    .foregroundStyle(.secondary)
            case .checking:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在检查更新")
                        .foregroundStyle(.secondary)
                }
            case .available(let update):
                Text("发现新版本 \(update.displayVersion)")
                    .font(.title3.weight(.semibold))
                Text("当前版本：\(updateManager.currentDisplayVersion)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            case .upToDate:
                Text("当前已是最新版本")
                    .font(.title3.weight(.semibold))
                Text("当前版本：\(updateManager.currentDisplayVersion)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            case .downloading(let progress):
                Text("正在下载更新")
                    .font(.title3.weight(.semibold))
                ProgressView(value: progress)
                    .frame(maxWidth: 420)
                Text("\(Int(progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            case .extracting:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在准备安装")
                        .font(.title3.weight(.semibold))
                }
            case .installing:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在安装并重启")
                        .font(.title3.weight(.semibold))
                }
            case .failed(let message):
                Text(failedTitle(for: message))
                    .font(.title3.weight(.semibold))
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var showsInstallButton: Bool {
        switch updateManager.state {
        case .available:
            return true
        case .failed:
            return updateManager.availableUpdate != nil
        case .idle, .checking, .upToDate, .downloading, .extracting, .installing:
            return false
        }
    }

    private func failedTitle(for message: String) -> String {
        if message.contains("安装") || message.contains("签名") {
            return "无法安装更新"
        }
        if message.contains("下载") {
            return "无法下载更新"
        }
        return "无法检查更新"
    }

    private func releaseNotes(for update: AvailableUpdate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            HStack {
                Text("更新内容")
                    .font(.headline)

                Spacer()

                if update.downloadSize > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(update.downloadSize), countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if update.releaseNotes.isEmpty {
                Text("这个版本没有提供详细更新说明。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(update.releaseNotes) { section in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(section.title)
                            .font(.callout.weight(.semibold))

                        ForEach(section.items, id: \.self) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 7)

                                Text(item)
                                    .font(.callout)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .leading)

            Text(value)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            Spacer()
        }
        .font(.callout)
    }

    private var updateDot: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 7, height: 7)
    }

    private var recheckTitle: String {
        switch updateManager.state {
        case .failed:
            return "重新检查"
        case .checking:
            return "检查中"
        default:
            return "检查更新"
        }
    }

    private var updateButtonTitle: String {
        switch updateManager.state {
        case .checking:
            return "正在准备"
        case .downloading(let progress):
            return "正在下载 \(Int(progress * 100))%"
        case .extracting:
            return "正在准备安装"
        case .installing:
            return "正在安装"
        default:
            return "立即更新"
        }
    }

}

private enum AboutSection: String, CaseIterable, Identifiable {
    case appInfo
    case updates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appInfo:
            return "应用信息"
        case .updates:
            return "版本更新"
        }
    }

    var subtitle: String {
        switch self {
        case .appInfo:
            return "版本、系统与仓库"
        case .updates:
            return "检查、日志与安装"
        }
    }

    var systemImage: String {
        switch self {
        case .appInfo:
            return "info.circle"
        case .updates:
            return "arrow.triangle.2.circlepath"
        }
    }
}
