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
                // SidebarView defined in Unit 2
                // SidebarView()
                Text("Sidebar (Unit 2)")
                    .frame(minWidth: appState.sidebarWidth)
            } detail: {
                VStack(spacing: 0) {
                    // TerminalAreaView defined in Unit 3
                    // TerminalAreaView()
                    Text("Terminal Area (Unit 3)")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if appState.settings.showStatusBar {
                        Divider()
                        // StatusBarView defined in Unit 6
                        // StatusBarView()
                        Text("Status Bar (Unit 6)")
                            .frame(maxWidth: .infinity, maxHeight: 24)
                            .background(.bar)
                    }
                }
            }

            if appState.isCommandPaletteVisible {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        appState.isCommandPaletteVisible = false
                    }

                // CommandPaletteView defined in Unit 6
                // CommandPaletteView()
                VStack {
                    Text("Command Palette (Unit 6)")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    Spacer()
                }
                .padding(.top, 80)
            }
        }
    }
}
