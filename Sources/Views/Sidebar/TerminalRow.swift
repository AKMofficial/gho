import SwiftUI

struct TerminalRow: View {
    let terminal: TerminalSession
    @Environment(AppState.self) private var appState
    @Environment(TerminalSessionManager.self) private var sessionManager
    @State private var isEditing = false

    private var isActive: Bool {
        appState.activeTerminalID == terminal.id
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(terminal.status.color)
                .frame(width: 8, height: 8)

            if isEditing {
                TextField("Name", text: Binding(
                    get: { terminal.label },
                    set: { terminal.label = $0 }
                ))
                .textFieldStyle(.plain)
                .onSubmit { isEditing = false }
            } else {
                Text(terminal.label)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            isEditing = true
        }
        .onTapGesture {
            appState.focusTerminal(id: terminal.id)
        }
        .contextMenu {
            Button("Rename") {
                isEditing = true
            }
            Divider()
            Button("Split Right") {
                appState.focusTerminal(id: terminal.id)
                appState.splitActive(direction: .horizontal, sessionManager: sessionManager)
            }
            Button("Split Down") {
                appState.focusTerminal(id: terminal.id)
                appState.splitActive(direction: .vertical, sessionManager: sessionManager)
            }
            Divider()
            Button("Close Terminal", role: .destructive) {
                appState.removeTerminal(id: terminal.id, sessionManager: sessionManager)
            }
        }
    }
}
