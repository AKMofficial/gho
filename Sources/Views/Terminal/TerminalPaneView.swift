import SwiftUI

/// Displays a single terminal pane.
///
/// The pane retrieves the ``SwiftTermEngine`` for its terminal ID from the
/// ``TerminalSessionManager`` and renders it through ``SwiftTermNSViewWrapper``.
/// An active-pane border highlight is drawn when this terminal is focused.
struct TerminalPaneView: View {

    /// The ID of the terminal session this pane displays.
    let terminalID: UUID

    @Environment(AppState.self) private var appState
    @Environment(TerminalSessionManager.self) private var sessionManager

    // MARK: - Computed

    private var isActive: Bool {
        appState.activeTerminalID == terminalID
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            if let engine = sessionManager.engine(for: terminalID) as? SwiftTermEngine {
                SwiftTermNSViewWrapper(engine: engine)
            } else {
                // Placeholder while the engine is being created or if lookup fails
                Color(nsColor: terminalBackgroundNSColor)
                .overlay {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.secondary)
                }
            }
        }
        .onAppear {
            sessionManager.startProcess(for: terminalID)
        }
        .border(
            isActive ? Color.accentColor.opacity(0.5) : Color.clear,
            width: 1
        )
        .contentShape(Rectangle())
        .onTapGesture {
            appState.focusTerminal(id: terminalID)
        }
    }
}
