import SwiftUI

// NOTE: TerminalSessionManager is defined in Unit 3, GitCLIService in Unit 4.
// This file references them by type name but the app won't compile until all units merge.

@main
struct GhoApp: App {
    @State private var appState = AppState()
    // Concrete types provided by other units:
    // @State private var sessionManager = TerminalSessionManager()
    // @State private var gitService: any GitServiceProtocol = GitCLIService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Add Path...") {
                    // Cmd+Shift+O: add path
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("New Terminal") {
                    // Cmd+T: new terminal
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Split Right") {
                    // Cmd+D: split right
                }
                .keyboardShortcut("d", modifiers: .command)

                Button("Split Down") {
                    // Cmd+Shift+D: split down
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Button("Close Pane") {
                    // Cmd+W: close pane
                }
                .keyboardShortcut("w", modifiers: .command)

                Button("Command Palette") {
                    appState.isCommandPaletteVisible.toggle()
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }

        Settings {
            Text("Settings will be provided by Unit 5")
                .frame(width: 400, height: 300)
        }
    }
}
