import SwiftUI

/// Central keyboard shortcut definitions for the Gho app.
/// Used by menu commands and views to ensure consistency.
enum KeyboardShortcuts {
    // MARK: - Global
    static let addPath = KeyboardShortcut("o", modifiers: [.command, .shift])
    static let newTerminal = KeyboardShortcut("t", modifiers: .command)
    static let closePane = KeyboardShortcut("w", modifiers: .command)
    static let closePathGroup = KeyboardShortcut("w", modifiers: [.command, .shift])
    static let settings = KeyboardShortcut(",", modifiers: .command)
    static let commandPalette = KeyboardShortcut("k", modifiers: .command)
    static let toggleSidebar = KeyboardShortcut("s", modifiers: [.command, .control])

    // MARK: - Terminal
    static let splitRight = KeyboardShortcut("d", modifiers: .command)
    static let splitDown = KeyboardShortcut("d", modifiers: [.command, .shift])
    static let maximizePane = KeyboardShortcut(.return, modifiers: [.command, .shift])
    static let increaseFontSize = KeyboardShortcut("+", modifiers: .command)
    static let decreaseFontSize = KeyboardShortcut("-", modifiers: .command)
    static let resetFontSize = KeyboardShortcut("0", modifiers: .command)
    static let findInTerminal = KeyboardShortcut("f", modifiers: .command)

    // MARK: - Tab Navigation
    static let nextTab = KeyboardShortcut("]", modifiers: [.command, .shift])
    static let previousTab = KeyboardShortcut("[", modifiers: [.command, .shift])

    // MARK: - Git
    static let stageAll = KeyboardShortcut("s", modifiers: [.command, .shift])
    static let unstageAll = KeyboardShortcut("u", modifiers: [.command, .shift])
    static let quickCommit = KeyboardShortcut(.return, modifiers: .command)
    static let push = KeyboardShortcut("p", modifiers: [.command, .shift])
}

/// SwiftUI Commands for the app menu bar.
struct GhoCommands: Commands {
    let appState: AppState
    let sessionManager: TerminalSessionManager

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Add Path...") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.begin { response in
                    if response == .OK, let url = panel.url {
                        let group = appState.addPathGroup(path: url)
                        let terminal = appState.addTerminal(to: group.id, sessionManager: sessionManager)
                        appState.focusTerminal(id: terminal.id)
                    }
                }
            }
            .keyboardShortcut(KeyboardShortcuts.addPath)

            Button("New Terminal") {
                if let group = appState.activePathGroup {
                    let t = appState.addTerminal(to: group.id, sessionManager: sessionManager)
                    appState.focusTerminal(id: t.id)
                }
            }
            .keyboardShortcut(KeyboardShortcuts.newTerminal)
            .disabled(appState.activePathGroup == nil)
        }

        CommandGroup(after: .toolbar) {
            Button("Toggle Sidebar") {
                appState.isSidebarVisible.toggle()
            }
            .keyboardShortcut(KeyboardShortcuts.toggleSidebar)

            Button("Command Palette") {
                appState.isCommandPaletteVisible.toggle()
            }
            .keyboardShortcut(KeyboardShortcuts.commandPalette)
        }

        CommandMenu("Terminal") {
            Button("Split Right") {
                appState.splitActive(direction: .horizontal, sessionManager: sessionManager)
            }
            .keyboardShortcut(KeyboardShortcuts.splitRight)
            .disabled(appState.activeTerminalID == nil)

            Button("Split Down") {
                appState.splitActive(direction: .vertical, sessionManager: sessionManager)
            }
            .keyboardShortcut(KeyboardShortcuts.splitDown)
            .disabled(appState.activeTerminalID == nil)

            Divider()

            Button("Maximize/Restore Pane") {
                if appState.maximizedPaneID != nil {
                    appState.maximizedPaneID = nil
                } else {
                    appState.maximizedPaneID = appState.activeTerminalID
                }
            }
            .keyboardShortcut(KeyboardShortcuts.maximizePane)
            .disabled(appState.activeTerminalID == nil)

            Divider()

            Button("Close Pane") {
                if let id = appState.activeTerminalID {
                    appState.closePane(id: id, sessionManager: sessionManager)
                }
            }
            .keyboardShortcut(KeyboardShortcuts.closePane)
            .disabled(appState.activeTerminalID == nil)

            Divider()

            Button("Increase Font Size") {
                appState.settings.terminalFontSize = min(24, appState.settings.terminalFontSize + 1)
                sessionManager.applySettings()
            }
            .keyboardShortcut(KeyboardShortcuts.increaseFontSize)

            Button("Decrease Font Size") {
                appState.settings.terminalFontSize = max(10, appState.settings.terminalFontSize - 1)
                sessionManager.applySettings()
            }
            .keyboardShortcut(KeyboardShortcuts.decreaseFontSize)

            Button("Reset Font Size") {
                appState.settings.terminalFontSize = 13
                sessionManager.applySettings()
            }
            .keyboardShortcut(KeyboardShortcuts.resetFontSize)

            Divider()

            Button("Navigate Left") {
                appState.navigatePane(direction: .left)
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .option])

            Button("Navigate Right") {
                appState.navigatePane(direction: .right)
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .option])

            Button("Navigate Up") {
                appState.navigatePane(direction: .up)
            }
            .keyboardShortcut(.upArrow, modifiers: [.command, .option])

            Button("Navigate Down") {
                appState.navigatePane(direction: .down)
            }
            .keyboardShortcut(.downArrow, modifiers: [.command, .option])
        }
    }
}
