import SwiftUI

struct ChangesListView: View {
    let gitState: GitState
    let repoPath: URL
    @State private var selectedFile: GitFileChange?
    @State private var showDiff = false
    @State private var diffIsStaged = false

    private let gitService = GitCLIService()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !gitState.stagedChanges.isEmpty {
                HStack {
                    Text("Staged")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                    Spacer()
                    Button("Unstage All") {
                        Task { try? await gitService.unstageAll(at: repoPath) }
                    }
                    .font(.caption2)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                ForEach(gitState.stagedChanges) { change in
                    FileChangeRow(
                        change: change,
                        isStaged: true,
                        onTap: {
                            selectedFile = change
                            diffIsStaged = true
                            showDiff = true
                        },
                        onStageToggle: {
                            Task { try? await gitService.unstage(file: change.path, at: repoPath) }
                        }
                    )
                }
            }

            if !gitState.unstagedChanges.isEmpty {
                HStack {
                    Text("Unstaged")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Stage All") {
                        Task { try? await gitService.stageAll(at: repoPath) }
                    }
                    .font(.caption2)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                ForEach(gitState.unstagedChanges) { change in
                    FileChangeRow(
                        change: change,
                        isStaged: false,
                        onTap: {
                            selectedFile = change
                            diffIsStaged = false
                            showDiff = true
                        },
                        onStageToggle: {
                            Task { try? await gitService.stage(file: change.path, at: repoPath) }
                        }
                    )
                    .contextMenu {
                        Button("Stage") {
                            Task { try? await gitService.stage(file: change.path, at: repoPath) }
                        }
                        Button("Discard Changes", role: .destructive) {
                            Task { try? await gitService.discardChanges(file: change.path, at: repoPath) }
                        }
                    }
                }
            }

        }
        .sheet(isPresented: $showDiff) {
            if let file = selectedFile {
                DiffView(
                    filePath: file.path,
                    staged: diffIsStaged,
                    repoPath: repoPath
                )
            }
        }
    }
}

/// A single file change row showing the change kind, file path, and stage toggle.
struct FileChangeRow: View {
    let change: GitFileChange
    let isStaged: Bool
    let onTap: () -> Void
    let onStageToggle: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onStageToggle) {
                Image(systemName: isStaged ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isStaged ? .green : .secondary)
                    .font(.caption)
            }
            .buttonStyle(.plain)

            Image(systemName: change.kind.symbol)
                .foregroundStyle(colorForKind(change.kind))
                .font(.caption)
                .frame(width: 14)

            Text(change.path)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text(change.kind.rawValue)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .padding(.vertical, 1)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private func colorForKind(_ kind: GitChangeKind) -> Color {
        switch kind {
        case .modified: return .orange
        case .added: return .green
        case .deleted: return .red
        case .renamed: return .blue
        case .copied: return .blue
        case .typeChanged: return .purple
        case .untracked: return .gray
        }
    }
}
