import SwiftUI

struct BranchPickerView: View {
    let gitState: GitState
    let repoPath: URL
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var isCreatingBranch = false
    @State private var newBranchName = ""
    @State private var errorMessage: String?

    private let gitService = GitCLIService()

    var filteredBranches: [String] {
        if searchText.isEmpty {
            return gitState.branches
        }
        return gitState.branches.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search branches...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(8)

            Divider()

            List {
                ForEach(filteredBranches, id: \.self) { branch in
                    HStack {
                        if branch == gitState.currentBranch {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.accent)
                                .font(.caption)
                        }
                        Text(branch)
                            .fontWeight(branch == gitState.currentBranch ? .semibold : .regular)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        switchToBranch(branch)
                    }
                }
            }
            .listStyle(.plain)

            Divider()

            if isCreatingBranch {
                HStack {
                    TextField("New branch name", text: $newBranchName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { createNewBranch() }
                    Button("Create") { createNewBranch() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(newBranchName.isEmpty)
                }
                .padding(8)
            } else {
                Button {
                    isCreatingBranch = true
                } label: {
                    Label("New Branch...", systemImage: "plus")
                }
                .buttonStyle(.plain)
                .padding(8)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
            }
        }
    }

    private func switchToBranch(_ branch: String) {
        guard branch != gitState.currentBranch else { return }
        errorMessage = nil
        Task {
            do {
                try await gitService.switchBranch(at: repoPath, to: branch)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func createNewBranch() {
        guard !newBranchName.isEmpty else { return }
        errorMessage = nil
        Task {
            do {
                try await gitService.createBranch(at: repoPath, name: newBranchName)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
