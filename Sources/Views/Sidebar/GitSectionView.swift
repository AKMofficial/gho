import SwiftUI

struct GitSectionView: View {
    let gitState: GitState
    let group: PathGroup
    @State private var showChanges = false
    @State private var showBranchPicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCommit = false
    @State private var showStash = false
    private let gitService = GitCLIService()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
                .padding(.vertical, 4)

            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.caption)
                Text(gitState.currentBranch)
                    .font(.caption)
                    .fontWeight(.medium)
                if gitState.aheadCount > 0 {
                    Text("\u{2191}\(gitState.aheadCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if gitState.behindCount > 0 {
                    Text("\u{2193}\(gitState.behindCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { showBranchPicker = true }
            .popover(isPresented: $showBranchPicker) {
                BranchPickerView(gitState: gitState, repoPath: group.path)
                    .frame(width: 250, height: 300)
            }

            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text("\(gitState.stagedCount) staged")
                        .font(.caption2)
                }
                HStack(spacing: 3) {
                    Circle().fill(.secondary).frame(width: 6, height: 6)
                    Text("\(gitState.unstagedCount) unstaged")
                        .font(.caption2)
                }
            }
            .foregroundStyle(.secondary)

            DisclosureGroup("View Changes", isExpanded: $showChanges) {
                ChangesListView(gitState: gitState, repoPath: group.path)
            }
            .font(.caption)

            HStack(spacing: 4) {
                quickActionButton("Push \u{2191}", systemImage: "arrow.up") {
                    runGitAction { try await gitService.push(at: group.path) }
                }
                quickActionButton("Pull \u{2193}", systemImage: "arrow.down") {
                    runGitAction { try await gitService.pull(at: group.path) }
                }
                quickActionButton("Stash", systemImage: "tray.and.arrow.down") {
                    showStash = true
                }
                quickActionButton("Commit", systemImage: "checkmark.circle") {
                    showCommit = true
                }
            }
            .font(.caption2)
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .popover(isPresented: $showCommit) {
                CommitView(repoPath: group.path, gitState: gitState)
            }
            .popover(isPresented: $showStash) {
                StashListView(repoPath: group.path)
            }
            .alert("Git Error", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .padding(.leading, 4)
    }

    private func runGitAction(_ operation: @escaping () async throws -> Void) {
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                try await operation()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func quickActionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
    }
}
