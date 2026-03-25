import SwiftUI

/// The main terminal area that renders the current split-pane layout.
///
/// - If a pane is maximized (`appState.maximizedPaneID`), only that pane
///   is shown, filling the entire area.
/// - Otherwise, the full ``SplitNode`` tree is rendered via
///   ``SplitContainerView``.
/// - When no terminals are open, an empty-state placeholder is shown.
/// - A ``TabBarView`` is shown above the terminal content when the active
///   path group has multiple terminals and the view is in single-pane mode.
struct TerminalAreaView: View {

    @Environment(AppState.self) private var appState

    /// Whether the tab bar should be visible.
    ///
    /// Shown when the active path group has more than one terminal and
    /// the view is displaying a single pane (no split layout or a
    /// maximized pane).
    private var shouldShowTabBar: Bool {
        guard let group = appState.activePathGroup,
              group.terminals.count > 1 else { return false }
        // Show tab bar when a pane is maximized (single pane from a split)
        // or when the split root is a single leaf (no visible splits).
        if appState.maximizedPaneID != nil { return true }
        if case .leaf = appState.splitRoot { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            if shouldShowTabBar {
                TabBarView()
            }

            Group {
                if let root = appState.splitRoot {
                    if let maximizedID = appState.maximizedPaneID {
                        // A single pane is maximized — show it full-screen
                        TerminalPaneView(terminalID: maximizedID)
                    } else {
                        SplitContainerView(node: root)
                    }
                } else {
                    emptyState
                }
            }
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { press in
            handleTabKeyPress(press)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No terminals open")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Add a path from the sidebar to get started")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: terminalBackgroundNSColor))
    }

    // MARK: - Tab Navigation

    private func handleTabKeyPress(_ press: KeyPress) -> KeyPress.Result {
        let modifiers = press.modifiers

        // Cmd+Shift+] — next tab
        if press.characters == "]" && modifiers == [.command, .shift] {
            navigateTab(direction: .next)
            return .handled
        }
        // Cmd+Shift+[ — previous tab
        if press.characters == "[" && modifiers == [.command, .shift] {
            navigateTab(direction: .previous)
            return .handled
        }
        // Cmd+1 through Cmd+9 — switch to tab N
        if modifiers == .command,
           let digit = press.characters.first?.wholeNumberValue,
           digit >= 1, digit <= 9 {
            switchToTab(index: digit - 1)
            return .handled
        }

        return .ignored
    }

    private enum TabDirection { case next, previous }

    private func navigateTab(direction: TabDirection) {
        guard let group = appState.activePathGroup,
              let activeID = appState.activeTerminalID,
              let currentIndex = group.terminals.firstIndex(where: { $0.id == activeID })
        else { return }

        let nextIndex: Int
        switch direction {
        case .next:
            nextIndex = (currentIndex + 1) % group.terminals.count
        case .previous:
            nextIndex = (currentIndex - 1 + group.terminals.count) % group.terminals.count
        }

        appState.focusTerminal(id: group.terminals[nextIndex].id)
    }

    private func switchToTab(index: Int) {
        guard let group = appState.activePathGroup,
              index < group.terminals.count
        else { return }

        appState.focusTerminal(id: group.terminals[index].id)
    }
}
