import SwiftUI

/// The main terminal area that renders the current split-pane layout.
///
/// - If a pane is maximized (`appState.maximizedPaneID`), only that pane
///   is shown, filling the entire area.
/// - Otherwise, the full ``SplitNode`` tree is rendered via
///   ``SplitContainerView``.
/// - When no terminals are open, an empty-state placeholder is shown.
struct TerminalAreaView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
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
}
