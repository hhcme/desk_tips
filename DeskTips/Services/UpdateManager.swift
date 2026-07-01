import AppKit
import Combine
import Foundation
import Sparkle

/// Coordinates Sparkle update checks without showing update notes in modal alerts.
@MainActor
final class UpdateManager: NSObject, ObservableObject {
    static let shared = UpdateManager()

    @Published private(set) var state: UpdateState = .idle
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var hasAvailableUpdate = false
    @Published private(set) var availableUpdate: AvailableUpdate?

    private var updater: SPUUpdater!
    private var canCheckForUpdatesObserver: AnyCancellable?
    private var sessionInProgressObserver: AnyCancellable?
    private var didRunLaunchCheck = false
    private var isLaunchCheckPending = false
    private var isInstallingRequested = false
    private var expectedDownloadLength: UInt64 = 0
    private var receivedDownloadLength: UInt64 = 0

    private override init() {
        super.init()

        updater = SPUUpdater(
            hostBundle: .main,
            applicationBundle: .main,
            userDriver: self,
            delegate: self
        )

        canCheckForUpdatesObserver = updater
            .publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] canCheckForUpdates in
                guard let self else { return }
                self.canCheckForUpdates = canCheckForUpdates

                if canCheckForUpdates, self.isLaunchCheckPending {
                    self.isLaunchCheckPending = false
                    self.didRunLaunchCheck = true
                    self.checkForUpdates()
                }
            }

        sessionInProgressObserver = updater
            .publisher(for: \.sessionInProgress)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessionInProgress in
                guard let self, sessionInProgress == false else { return }
                self.expectedDownloadLength = 0
                self.receivedDownloadLength = 0
            }

        do {
            try updater.start()
        } catch {
            setState(.failed("更新功能启动失败，请重新安装正式版本后再试。"))
        }
    }

    var currentDisplayVersion: String {
        Self.currentDisplayVersion
    }

    var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "未知"
    }

    var repositoryURL: URL {
        URL(string: "https://github.com/hhcme/desk_tips")!
    }

    func performLaunchCheckIfNeeded() {
        guard didRunLaunchCheck == false, isLaunchCheckPending == false else { return }

        if canCheckForUpdates {
            didRunLaunchCheck = true
            checkForUpdates()
        } else {
            isLaunchCheckPending = true
            setState(.checking)
        }
    }

    func checkForUpdates() {
        guard canCheckForUpdates else {
            setState(.failed("更新服务还没有准备好，请稍后再试。"))
            return
        }

        isInstallingRequested = false
        setState(.checking)
        updater.checkForUpdateInformation()
    }

    func installAvailableUpdate() {
        guard availableUpdate != nil else {
            setState(.failed("当前没有可安装的新版本。"))
            return
        }

        guard canCheckForUpdates else {
            setState(.failed("更新服务正忙，请稍后再试。"))
            return
        }

        isInstallingRequested = true
        expectedDownloadLength = 0
        receivedDownloadLength = 0
        setState(.checking)
        updater.checkForUpdates()
    }

    private func setState(_ newState: UpdateState) {
        state = newState
        switch newState {
        case .available(let update):
            availableUpdate = update
            hasAvailableUpdate = true
        case .checking, .upToDate, .failed:
            hasAvailableUpdate = false
            if case .upToDate = newState {
                availableUpdate = nil
            }
        case .downloading, .extracting, .installing:
            hasAvailableUpdate = false
        case .idle:
            hasAvailableUpdate = false
        }
    }

    private func updateAvailable(from item: SUAppcastItem) -> AvailableUpdate {
        AvailableUpdate(
            displayVersion: item.displayVersionString,
            buildVersion: item.versionString,
            title: item.title,
            releaseDate: item.date,
            downloadSize: item.contentLength,
            releaseNotes: ReleaseNotesParser.parse(item.itemDescription ?? "")
        )
    }

    private static var currentBuildNumber: Int {
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return Int(build) ?? 0
    }

    private static var currentDisplayVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知版本"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        if let build, build.isEmpty == false {
            return "\(version) (\(build))"
        }
        return version
    }

    private func failureMessage(for error: Error) -> String {
        if isNoUpdateError(error) {
            return "当前已是最新版本。"
        }

        logUpdateError(error)

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "当前网络不可用，请连接网络后再试。"
            case .timedOut:
                return "连接更新服务超时，请稍后再试。"
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return "无法连接更新服务，请稍后再试。"
            case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateUntrusted:
                return "更新服务的安全连接验证失败，请稍后再试。"
            case .cancelled:
                return "检查更新已取消。"
            default:
                return "网络请求失败，请稍后再试。"
            }
        }

        let nsError = error as NSError
        if nsError.domain == SUSparkleErrorDomain {
            switch nsError.code {
            case 4005:
                return "安装更新失败。当前版本的更新权限或发布包签名不完整，请从 GitHub 下载最新版覆盖安装；之后的版本会恢复应用内更新。"
            case 4009:
                return "更新包签名验证失败，请重新发布使用同一 Developer ID 签名并由 Sparkle 签名的安装包。"
            case 4010:
                return "更新安装器连接已中断，请重新打开应用后再试。"
            default:
                break
            }
        }

        let message = nsError.localizedDescription
        return message.isEmpty ? "检查更新时发生未知错误，请稍后再试。" : message
    }

    private func isNoUpdateError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == SUSparkleErrorDomain && nsError.code == 1001
    }

    private func logUpdateError(_ error: Error) {
        let nsError = error as NSError
        let reason = nsError.localizedFailureReason ?? "无"
        let recovery = nsError.localizedRecoverySuggestion ?? "无"
        let underlying = nsError.userInfo[NSUnderlyingErrorKey] ?? "无"
        NSLog(
            "DeskTips update error domain=%@ code=%ld description=%@ reason=%@ recovery=%@ underlying=%@",
            nsError.domain,
            nsError.code,
            nsError.localizedDescription,
            reason,
            recovery,
            String(describing: underlying)
        )
    }
}

enum UpdateState {
    case idle
    case checking
    case available(AvailableUpdate)
    case upToDate
    case downloading(progress: Double)
    case extracting
    case installing
    case failed(String)

    var isBusy: Bool {
        switch self {
        case .checking, .downloading, .extracting, .installing:
            return true
        case .idle, .available, .upToDate, .failed:
            return false
        }
    }
}

struct AvailableUpdate: Identifiable {
    var id: String { buildVersion }

    let displayVersion: String
    let buildVersion: String
    let title: String?
    let releaseDate: Date?
    let downloadSize: UInt64
    let releaseNotes: [ReleaseNotesSection]
}

struct ReleaseNotesSection: Identifiable, Equatable {
    var id: String { title }
    var title: String
    var items: [String]
}

enum ReleaseNotesParser {
    static func parse(_ rawNotes: String) -> [ReleaseNotesSection] {
        let lines = rawNotes
            .decodedReleaseNotes
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        var sections: [ReleaseNotesSection] = []
        var current = ReleaseNotesSection(title: "更新内容", items: [])

        func flushCurrentSection() {
            guard current.items.isEmpty == false else { return }
            sections.append(current)
            current = ReleaseNotesSection(title: "更新内容", items: [])
        }

        for line in lines where line.isEmpty == false {
            if line.hasPrefix("# ") {
                continue
            }

            if let heading = markdownHeading(from: line) {
                flushCurrentSection()
                current = ReleaseNotesSection(title: heading, items: [])
                continue
            }

            if let bullet = bulletText(from: line) {
                current.items.append(bullet)
                continue
            }

            if current.items.isEmpty {
                current.title = line
            } else if current.title == "更新内容" {
                current.items.append(line)
            } else {
                flushCurrentSection()
                current = ReleaseNotesSection(title: line, items: [])
            }
        }

        flushCurrentSection()
        return sections
    }

    private static func markdownHeading(from line: String) -> String? {
        guard line.hasPrefix("##") else { return nil }
        let heading = line
            .drop(while: { $0 == "#" })
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return heading.isEmpty ? nil : heading
    }

    private static func bulletText(from line: String) -> String? {
        let bulletPrefixes = ["- ", "* ", "• "]
        for prefix in bulletPrefixes where line.hasPrefix(prefix) {
            let text = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
        return nil
    }
}

private extension String {
    var decodedReleaseNotes: String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }
}

extension UpdateManager: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        guard isInstallingRequested == false else { return }
        setState(.available(updateAvailable(from: item)))
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        if isNoUpdateError(error) {
            setState(.upToDate)
        } else {
            setState(.failed(failureMessage(for: error)))
        }
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        isInstallingRequested = false
        setState(.failed(failureMessage(for: error)))
    }

    func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: Error?
    ) {
        if let error, isNoUpdateError(error) == false {
            setState(.failed(failureMessage(for: error)))
        }
    }
}

extension UpdateManager: SPUUserDriver {
    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        setState(.checking)
    }

    func showUpdateFound(
        with appcastItem: SUAppcastItem,
        state: SPUUserUpdateState,
        reply: @escaping (SPUUserUpdateChoice) -> Void
    ) {
        let update = updateAvailable(from: appcastItem)
        availableUpdate = update

        guard isInstallingRequested else {
            setState(.available(update))
            reply(.dismiss)
            return
        }

        reply(.install)
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}

    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        if isNoUpdateError(error) {
            setState(.upToDate)
        } else {
            setState(.failed(failureMessage(for: error)))
        }
        acknowledgement()
    }

    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        isInstallingRequested = false
        setState(.failed(failureMessage(for: error)))
        acknowledgement()
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        expectedDownloadLength = 0
        receivedDownloadLength = 0
        setState(.downloading(progress: 0))
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        self.expectedDownloadLength = expectedContentLength
        receivedDownloadLength = 0
        setState(.downloading(progress: 0))
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        receivedDownloadLength += length
        guard expectedDownloadLength > 0 else {
            setState(.downloading(progress: 0))
            return
        }

        let progress = min(1, Double(receivedDownloadLength) / Double(expectedDownloadLength))
        setState(.downloading(progress: progress))
    }

    func showDownloadDidStartExtractingUpdate() {
        setState(.extracting)
    }

    func showExtractionReceivedProgress(_ progress: Double) {
        setState(.extracting)
    }

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        setState(.installing)
        reply(.install)
    }

    func showInstallingUpdate(
        withApplicationTerminated applicationTerminated: Bool,
        retryTerminatingApplication: @escaping () -> Void
    ) {
        setState(.installing)
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }

    func dismissUpdateInstallation() {
        if isInstallingRequested {
            isInstallingRequested = false
        }
    }

    func showUpdateInFocus() {}
}
