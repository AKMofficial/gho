import SwiftUI

struct StashListView: View {
    let repoPath: URL
    @State private var stashes: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var stashMessage = ""
    private let gitService = GitCLIService()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stashes")
                .font(.headline)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if stashes.isEmpty {
                Text("No stashes")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                List(stashes, id: \.self) { stash in
                    HStack {
                        Text(stash)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                    }
                }
                .frame(maxHeight: 150)
            }

            Divider()

            HStack {
                TextField("Stash message (optional)", text: $stashMessage)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                Button("Stash") { createStash() }
                    .controlSize(.small)
            }

            if !stashes.isEmpty {
                Button("Pop Latest Stash") { popStash() }
                    .controlSize(.small)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(width: 300)
        .task { await loadStashes() }
    }

    private func loadStashes() async {
        isLoading = true
        defer { isLoading = false }
        do {
            stashes = try await gitService.stashList(at: repoPath)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createStash() {
        Task {
            do {
                let msg = stashMessage.isEmpty ? nil : stashMessage
                try await gitService.stash(at: repoPath, message: msg)
                stashMessage = ""
                await loadStashes()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func popStash() {
        Task {
            do {
                try await gitService.stashPop(at: repoPath)
                await loadStashes()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
