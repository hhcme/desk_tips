import SwiftUI
import DeskTipsCore

/// Top-level tabbed view for the main window.
struct MainTabView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var settingsStore: SettingsStore
    let overlayController: OverlayWindowController

    @StateObject private var updateManager = UpdateManager.shared

    var body: some View {
        TabView {
            TodoListView(store: store)
                .tabItem { Label("待办", systemImage: "checklist") }

            CategoryManageView(store: store)
                .tabItem { Label("分类", systemImage: "folder") }

            HistoryView(store: store)
                .tabItem { Label("历史", systemImage: "clock.arrow.circlepath") }

            MainSettingsView(
                settingsStore: settingsStore,
                overlayController: overlayController
            )
            .tabItem { Label("设置", systemImage: "gear") }

            MainAboutView()
                .tabItem { Label("关于", systemImage: "info.circle") }
                .badge(updateManager.hasAvailableUpdate ? "" : nil)
        }
        .frame(minWidth: 1040, minHeight: 560)
    }
}
