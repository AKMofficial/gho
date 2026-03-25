import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(TerminalSessionManager.self) private var sessionManager

    var body: some View {
        @Bindable var state = appState

        VStack(spacing: 0) {
            HStack {
                Text("Workspaces").font(.headline)
                Spacer()
                Button { addPath() } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .buttonStyle(.borderless)
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            List(selection: $state.activeTerminalID) {
                ForEach(appState.pathGroups) { group in
                    PathGroupRow(group: group)
                }
                .onMove { from, to in
                    appState.movePathGroup(from: from, to: to)
                }
            }
            .listStyle(.sidebar)
        }
    }

    private func addPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let group = appState.addPathGroup(path: url)
                let terminal = appState.addTerminal(to: group.id, sessionManager: sessionManager)
                appState.focusTerminal(id: terminal.id)
            }
        }
    }
}
