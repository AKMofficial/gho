import SwiftUI

struct CommitView: View {
    let repoPath: URL
    let gitState: GitState
    @State private var commitMessage = ""
    @State private var stageAll = false
    @State private var isCommitting = false
    @State private var errorMessage: String?
    @State private var didCommit = false
    @Environment(\.dismiss) private var dismiss
    private let gitService = GitCLIService()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Commit Changes")
                .font(.headline)

            Text("\(gitState.stagedCount) staged changes")
                .font(.caption)
                .foregroundStyle(.secondary)

            if gitState.unstagedCount > 0 {
                Toggle("Stage all changes first", isOn: $stageAll)
                    .font(.caption)
            }

            TextEditor(text: $commitMessage)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 80)
                .border(Color.secondary.opacity(0.3))

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if didCommit {
                Label("Committed successfully", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Commit") { performCommit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCommitting)
            }
        }
        .padding()
        .frame(width: 350)
    }

    private func performCommit() {
        Task {
            isCommitting = true
            defer { isCommitting = false }
            do {
                if stageAll {
                    try await gitService.stageAll(at: repoPath)
                }
                try await gitService.commit(message: commitMessage.trimmingCharacters(in: .whitespacesAndNewlines), at: repoPath)
                didCommit = true
                try? await Task.sleep(for: .seconds(1))
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
