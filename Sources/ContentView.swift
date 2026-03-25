import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        ZStack {
            NavigationSplitView(
                columnVisibility: Binding(
                    get: { appState.isSidebarVisible ? .all : .detailOnly },
                    set: { appState.isSidebarVisible = ($0 != .detailOnly) }
                )
            ) {
                SidebarView()
                    .frame(minWidth: appState.sidebarWidth)
            } detail: {
                VStack(spacing: 0) {
                    TerminalAreaView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if appState.settings.showStatusBar {
                        StatusBarView()
                    }
                }
            }

            if appState.isCommandPaletteVisible {
                CommandPaletteView()
            }
        }
    }
}
