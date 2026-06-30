import SwiftUI
import DeskTipsCore

/// Top-level tabbed view for the main window.
struct MainTabView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var settingsStore: SettingsStore
    let overlayController: OverlayWindowController

    var body: some View {
        TabView {
            TodoListView(store: store)
                .tabItem { Label("待办", systemImage: "checklist") }

            HistoryView(store: store)
                .tabItem { Label("历史", systemImage: "clock.arrow.circlepath") }

            MainSettingsView(
                settingsStore: settingsStore,
                overlayController: overlayController
            )
            .tabItem { Label("设置", systemImage: "gear") }
        }
        .frame(minWidth: 420, minHeight: 400)
    }
}
