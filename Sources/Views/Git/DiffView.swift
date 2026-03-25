import SwiftUI

struct DiffView: View {
    let filePath: String
    let staged: Bool
    let repoPath: URL
    @Environment(\.dismiss) private var dismiss
    @State private var diff: GitDiff?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let gitService = GitCLIService()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "doc.text")
                Text(filePath)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(staged ? "Staged" : "Unstaged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(staged ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let diff = diff {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(diff.hunks.enumerated()), id: \.offset) { _, hunk in
                            Text(hunk.header)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.05))

                            ForEach(Array(hunk.lines.enumerated()), id: \.offset) { _, line in
                                DiffLineView(line: line)
                            }
                        }
                    }
                }
                .font(.system(.body, design: .monospaced))
            } else {
                Text("No changes")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .task {
            await loadDiff()
        }
    }

    private func loadDiff() async {
        do {
            diff = try await gitService.diff(file: filePath, staged: staged, at: repoPath)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct DiffLineView: View {
    let line: DiffLine

    var body: some View {
        HStack(spacing: 0) {
            Text(line.oldLineNumber.map { "\($0)" } ?? "")
                .frame(width: 50, alignment: .trailing)
                .foregroundStyle(.tertiary)
                .font(.system(.caption, design: .monospaced))

            Text(line.newLineNumber.map { "\($0)" } ?? "")
                .frame(width: 50, alignment: .trailing)
                .foregroundStyle(.tertiary)
                .font(.system(.caption, design: .monospaced))

            Text(prefix)
                .frame(width: 16)
                .foregroundStyle(prefixColor)

            Text(line.content)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .background(backgroundColor)
    }

    private var prefix: String {
        switch line.kind {
        case .addition: return "+"
        case .deletion: return "-"
        case .context: return " "
        }
    }

    private var prefixColor: Color {
        switch line.kind {
        case .addition: return .green
        case .deletion: return .red
        case .context: return .secondary
        }
    }

    private var backgroundColor: Color {
        switch line.kind {
        case .addition: return Color.green.opacity(0.08)
        case .deletion: return Color.red.opacity(0.08)
        case .context: return .clear
        }
    }
}
