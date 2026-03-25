import SwiftUI

struct PRFormView: View {
    let repoPath: URL
    let currentBranch: String
    let branches: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var prDescription: String = ""
    @State private var baseBranch: String = "main"
    @State private var isSubmitting = false
    @State private var createdPRURL: URL?
    @State private var errorMessage: String?

    private let gitService = GitCLIService()

    init(repoPath: URL, currentBranch: String, branches: [String], defaultBaseBranch: String = "main") {
        self.repoPath = repoPath
        self.currentBranch = currentBranch
        self.branches = branches
        // Auto-populate title from branch name: "feature/auth-system" -> "Auth system"
        let branchTitle = currentBranch
            .replacingOccurrences(of: "feature/", with: "")
            .replacingOccurrences(of: "fix/", with: "Fix: ")
            .replacingOccurrences(of: "bugfix/", with: "Fix: ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        _title = State(initialValue: branchTitle.prefix(1).capitalized + branchTitle.dropFirst())
        _baseBranch = State(initialValue: defaultBaseBranch)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Create Pull Request")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            if let prURL = createdPRURL {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("Pull Request Created!")
                        .font(.title3)
                    Link(prURL.absoluteString, destination: prURL)
                        .font(.caption)
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                Form {
                    Section("Details") {
                        TextField("Title", text: $title)

                        VStack(alignment: .leading) {
                            Text("Description")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextEditor(text: $prDescription)
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 100)
                                .border(Color.secondary.opacity(0.2))
                        }
                    }

                    Section("Branch") {
                        HStack {
                            Text("From:")
                            Text(currentBranch)
                                .fontWeight(.medium)
                                .foregroundStyle(.accent)
                        }

                        Picker("Into:", selection: $baseBranch) {
                            ForEach(branches, id: \.self) { branch in
                                Text(branch).tag(branch)
                            }
                        }
                    }

                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                }
                .formStyle(.grouped)

                HStack {
                    Spacer()
                    Button("Create Pull Request") {
                        submitPR()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.isEmpty || isSubmitting)
                    .keyboardShortcut(.return, modifiers: .command)
                }
                .padding()
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private func submitPR() {
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                let url = try await gitService.createPR(
                    title: title,
                    body: prDescription,
                    baseBranch: baseBranch,
                    at: repoPath
                )
                createdPRURL = url
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
