import SwiftUI

struct PathGroupRow: View {
    let group: PathGroup
    @Environment(AppState.self) private var appState
    @Environment(TerminalSessionManager.self) private var sessionManager
    @State private var isEditing = false

    var body: some View {
        DisclosureGroup(isExpanded: Binding(
            get: { !group.isCollapsed },
            set: { group.isCollapsed = !$0 }
        )) {
            ForEach(group.terminals) { terminal in
                TerminalRow(terminal: terminal)
            }

            Button {
                let t = appState.addTerminal(to: group.id, sessionManager: sessionManager)
                appState.focusTerminal(id: t.id)
            } label: {
                Label("New Terminal", systemImage: "plus")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .buttonStyle(.plain)

            if let gitState = group.gitState, appState.settings.showGitInSidebar {
                GitSectionView(gitState: gitState, group: group)
            }
        } label: {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.secondary)
                if isEditing {
                    TextField("Name", text: Binding(
                        get: { group.displayName ?? "" },
                        set: { group.displayName = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.plain)
                    .onSubmit { isEditing = false }
                } else {
                    Text(group.effectiveName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Text("\(group.terminals.count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .contextMenu {
            Button("Open in Finder") {
                NSWorkspace.shared.open(group.path)
            }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(group.path.path, forType: .string)
            }
            Button("Rename...") {
                isEditing = true
            }
            Divider()
            Button("Remove Path", role: .destructive) {
                appState.removePathGroup(id: group.id)
            }
        }
    }
}
