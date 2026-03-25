import SwiftUI

/// A horizontal tab bar showing terminal labels for the active path group.
///
/// Displayed when the active path group has multiple terminals and the view
/// is showing a single pane (not split mode). Each tab shows the terminal
/// label and a close button; clicking a tab focuses that terminal.
struct TabBarView: View {

    @Environment(AppState.self) private var appState
    @Environment(TerminalSessionManager.self) private var sessionManager

    var body: some View {
        HStack(spacing: 0) {
            tabs
            addButton
            Spacer()
        }
        .frame(height: 28)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Tabs

    private var tabs: some View {
        ForEach(terminals) { terminal in
            tabItem(for: terminal)
        }
    }

    private func tabItem(for terminal: TerminalSession) -> some View {
        let isActive = terminal.id == appState.activeTerminalID

        return HStack(spacing: 4) {
            Circle()
                .fill(terminal.status.color)
                .frame(width: 6, height: 6)

            Text(terminal.label)
                .font(.system(size: 11))
                .lineLimit(1)

            Button {
                appState.removeTerminal(id: terminal.id, sessionManager: sessionManager)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .contentShape(Rectangle())
        .onTapGesture {
            appState.focusTerminal(id: terminal.id)
        }
        .background(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
        .foregroundStyle(isActive ? .primary : .secondary)
        .overlay(alignment: .trailing) {
            Divider()
                .frame(height: 14)
        }
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button {
            if let group = appState.activePathGroup {
                appState.addTerminal(to: group.id, sessionManager: sessionManager)
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var terminals: [TerminalSession] {
        appState.activePathGroup?.terminals ?? []
    }
}
