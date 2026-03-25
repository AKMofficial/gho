import SwiftUI

struct CommandPaletteView: View {
    @Environment(AppState.self) private var appState
    @Environment(TerminalSessionManager.self) private var sessionManager
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    appState.isCommandPaletteVisible = false
                }

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search commands, paths, terminals...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .focused($isFocused)
                        .onSubmit { executeSelected() }
                        .onChange(of: searchText) { selectedIndex = 0 }
                }
                .padding(12)

                Divider()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                            CommandRow(
                                command: command,
                                isSelected: index == selectedIndex
                            )
                            .onTapGesture {
                                selectedIndex = index
                                executeSelected()
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            .frame(width: 500)
            .padding(.top, 100)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear { isFocused = true }
        .onKeyPress(.upArrow) {
            selectedIndex = max(0, selectedIndex - 1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            selectedIndex = min(filteredCommands.count - 1, selectedIndex + 1)
            return .handled
        }
        .onKeyPress(.escape) {
            appState.isCommandPaletteVisible = false
            return .handled
        }
    }

    // MARK: - Commands

    struct PaletteCommand: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String?
        let icon: String
        let action: () -> Void
    }

    var allCommands: [PaletteCommand] {
        var commands: [PaletteCommand] = []

        commands.append(PaletteCommand(
            title: "New Terminal",
            subtitle: "Create a new terminal in the current path",
            icon: "terminal",
            action: {
                if let group = appState.activePathGroup {
                    let t = appState.addTerminal(to: group.id, sessionManager: sessionManager)
                    appState.focusTerminal(id: t.id)
                }
                appState.isCommandPaletteVisible = false
            }
        ))

        commands.append(PaletteCommand(
            title: "Add Path...",
            subtitle: "Open a new workspace directory",
            icon: "folder.badge.plus",
            action: {
                appState.isCommandPaletteVisible = false
            }
        ))

        commands.append(PaletteCommand(
            title: "Split Right",
            subtitle: "Split the active terminal horizontally",
            icon: "rectangle.split.1x2",
            action: {
                appState.splitActive(direction: .horizontal, sessionManager: sessionManager)
                appState.isCommandPaletteVisible = false
            }
        ))

        commands.append(PaletteCommand(
            title: "Split Down",
            subtitle: "Split the active terminal vertically",
            icon: "rectangle.split.2x1",
            action: {
                appState.splitActive(direction: .vertical, sessionManager: sessionManager)
                appState.isCommandPaletteVisible = false
            }
        ))

        commands.append(PaletteCommand(
            title: "Toggle Sidebar",
            subtitle: nil,
            icon: "sidebar.left",
            action: {
                appState.isSidebarVisible.toggle()
                appState.isCommandPaletteVisible = false
            }
        ))

        commands.append(PaletteCommand(
            title: "Settings",
            subtitle: "Open application preferences",
            icon: "gearshape",
            action: {
                appState.isCommandPaletteVisible = false
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        ))

        for group in appState.pathGroups {
            for terminal in group.terminals {
                commands.append(PaletteCommand(
                    title: "Focus: \(terminal.label)",
                    subtitle: group.effectiveName,
                    icon: "terminal",
                    action: {
                        appState.focusTerminal(id: terminal.id)
                        appState.isCommandPaletteVisible = false
                    }
                ))
            }

            if let gitState = group.gitState {
                commands.append(PaletteCommand(
                    title: "Switch Branch: \(group.effectiveName)",
                    subtitle: "Current: \(gitState.currentBranch)",
                    icon: "arrow.triangle.branch",
                    action: {
                        appState.isCommandPaletteVisible = false
                    }
                ))

                if gitState.aheadCount > 0 {
                    commands.append(PaletteCommand(
                        title: "Push: \(group.effectiveName)",
                        subtitle: "\(gitState.aheadCount) commits ahead",
                        icon: "arrow.up.circle",
                        action: {
                            appState.isCommandPaletteVisible = false
                        }
                    ))
                }
            }
        }

        return commands
    }

    var filteredCommands: [PaletteCommand] {
        if searchText.isEmpty { return allCommands }
        let query = searchText.lowercased()
        return allCommands.filter { cmd in
            cmd.title.lowercased().contains(query) ||
            (cmd.subtitle?.lowercased().contains(query) ?? false)
        }
    }

    private func executeSelected() {
        guard selectedIndex < filteredCommands.count else { return }
        filteredCommands[selectedIndex].action()
    }
}

struct CommandRow: View {
    let command: CommandPaletteView.PaletteCommand
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: command.icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(command.title)
                    .font(.system(size: 13))
                if let subtitle = command.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
    }
}
