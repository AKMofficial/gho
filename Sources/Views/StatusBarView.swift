import SwiftUI

struct StatusBarView: View {
    @Environment(AppState.self) private var appState
    @State private var showBranchPicker = false
    @State private var showChanges = false

    var body: some View {
        HStack(spacing: 0) {
            if let group = appState.activePathGroup {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                    Text(group.effectiveName)
                }
                .foregroundStyle(.secondary)
                .font(.system(size: 11))

                if let gitState = group.gitState {
                    separator

                    HStack(spacing: 3) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 10))
                        Text(gitState.currentBranch)
                    }
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11))
                    .contentShape(Rectangle())
                    .onTapGesture { showBranchPicker = true }
                    .popover(isPresented: $showBranchPicker) {
                        BranchPickerView(gitState: gitState, repoPath: group.path)
                            .frame(width: 250, height: 300)
                    }

                    separator

                    changeIndicator(color: .green, count: gitState.stagedCount, label: "staged")

                    separator

                    changeIndicator(color: .gray, count: gitState.unstagedCount, label: "unstaged")

                    if gitState.aheadCount > 0 {
                        separator
                        Text("\u{2191}\(gitState.aheadCount)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("No active terminal")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .sheet(isPresented: $showChanges) {
            if let group = appState.activePathGroup, let gitState = group.gitState {
                ChangesListView(gitState: gitState, repoPath: group.path)
                    .frame(minWidth: 400, minHeight: 300)
            }
        }
    }

    private func changeIndicator(color: Color, count: Int, label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(count) \(label)")
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .contentShape(Rectangle())
        .onTapGesture { showChanges = true }
    }

    private var separator: some View {
        Text("\u{00B7}")
            .foregroundStyle(.quaternary)
            .padding(.horizontal, 6)
            .font(.system(size: 11))
    }
}
