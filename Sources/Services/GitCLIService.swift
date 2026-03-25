import Foundation

final class GitCLIService: GitServiceProtocol, @unchecked Sendable {

    // MARK: - Private Helpers

    /// Execute a process and return stdout as a trimmed string.
    /// Throws ``GitError/commandFailed(_:)`` when the process exits with a non-zero status.
    private func execute(
        _ executable: URL,
        arguments: [String],
        at path: URL
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            process.currentDirectoryURL = path

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            process.terminationHandler = { _ in
                let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    let errMsg = String(data: errData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown git error"
                    continuation.resume(throwing: GitError.commandFailed(errMsg))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static let gitURL = URL(fileURLWithPath: "/usr/bin/git")

    /// Execute a git command and return stdout as a trimmed string.
    private func run(_ arguments: [String], at path: URL) async throws -> String {
        try await execute(Self.gitURL, arguments: arguments, at: path)
    }

    /// Execute a git command, return true on success, false on failure (no throw).
    private func runBool(_ arguments: [String], at path: URL) async -> Bool {
        do {
            _ = try await run(arguments, at: path)
            return true
        } catch {
            return false
        }
    }

    // MARK: - GitServiceProtocol

    func isGitRepository(at path: URL) async -> Bool {
        await runBool(["rev-parse", "--is-inside-work-tree"], at: path)
    }

    func getStatus(at path: URL) async throws -> GitState {
        let output = try await run(["status", "--porcelain=v2", "--branch"], at: path)
        return parseStatusV2(output)
    }

    func getBranches(at path: URL) async throws -> [String] {
        let output = try await run(["branch", "--format=%(refname:short)"], at: path)
        guard !output.isEmpty else { return [] }
        return output.split(separator: "\n").map { String($0) }
    }

    func currentBranch(at path: URL) async throws -> String {
        try await run(["rev-parse", "--abbrev-ref", "HEAD"], at: path)
    }

    func switchBranch(at path: URL, to branch: String) async throws {
        _ = try await run(["checkout", branch], at: path)
    }

    func createBranch(at path: URL, name: String) async throws {
        _ = try await run(["checkout", "-b", name], at: path)
    }

    func stage(file: String, at path: URL) async throws {
        _ = try await run(["add", "--", file], at: path)
    }

    func unstage(file: String, at path: URL) async throws {
        _ = try await run(["reset", "HEAD", "--", file], at: path)
    }

    func stageAll(at path: URL) async throws {
        _ = try await run(["add", "-A"], at: path)
    }

    func unstageAll(at path: URL) async throws {
        _ = try await run(["reset", "HEAD"], at: path)
    }

    func discardChanges(file: String, at path: URL) async throws {
        _ = try await run(["checkout", "--", file], at: path)
    }

    func diff(file: String, staged: Bool, at path: URL) async throws -> GitDiff {
        var args = ["diff"]
        if staged { args.append("--cached") }
        args += ["--", file]
        let output = try await run(args, at: path)
        return parseDiff(output, filePath: file)
    }

    func commit(message: String, at path: URL) async throws {
        _ = try await run(["commit", "-m", message], at: path)
    }

    func push(at path: URL) async throws {
        _ = try await run(["push"], at: path)
    }

    func pull(at path: URL) async throws {
        _ = try await run(["pull"], at: path)
    }

    func stash(at path: URL, message: String?) async throws {
        var args = ["stash", "push"]
        if let msg = message {
            args += ["-m", msg]
        }
        _ = try await run(args, at: path)
    }

    func stashPop(at path: URL) async throws {
        _ = try await run(["stash", "pop"], at: path)
    }

    func stashList(at path: URL) async throws -> [String] {
        let output = try await run(["stash", "list"], at: path)
        guard !output.isEmpty else { return [] }
        return output.split(separator: "\n").map { String($0) }
    }

    func createPR(title: String, body: String, baseBranch: String, at path: URL) async throws -> URL {
        let output = try await execute(
            URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["gh", "pr", "create", "--title", title, "--body", body, "--base", baseBranch],
            at: path
        )
        guard let url = URL(string: output) else {
            throw GitError.commandFailed("gh pr create returned invalid URL: \(output)")
        }
        return url
    }

    // MARK: - Parsing

    /// Parse `git status --porcelain=v2 --branch` output.
    /// Format reference: https://git-scm.com/docs/git-status#_porcelain_format_version_2
    private func parseStatusV2(_ output: String) -> GitState {
        let state = GitState()
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)

        for line in lines {
            let str = String(line)

            if str.hasPrefix("# branch.head ") {
                state.currentBranch = String(str.dropFirst("# branch.head ".count))
            } else if str.hasPrefix("# branch.ab ") {
                let parts = str.dropFirst("# branch.ab ".count).split(separator: " ")
                if parts.count >= 2 {
                    state.aheadCount = Int(parts[0].dropFirst()) ?? 0
                    state.behindCount = Int(parts[1].dropFirst()) ?? 0
                }
            } else if str.hasPrefix("1 ") || str.hasPrefix("2 ") {
                parseChangedEntry(str, into: state)
            } else if str.hasPrefix("? ") {
                let path = String(str.dropFirst(2))
                state.untrackedFiles.append(path)
                state.unstagedChanges.append(GitFileChange(
                    path: path,
                    oldPath: nil,
                    kind: .untracked
                ))
            }
        }

        return state
    }

    /// Parse a single changed entry from porcelain v2 output.
    private func parseChangedEntry(_ line: String, into state: GitState) {
        let parts = line.split(separator: " ", maxSplits: 8)
        guard parts.count >= 7 else { return }

        let xy = String(parts[1])
        let indexStatus = xy.first ?? "."
        let workTreeStatus = xy.last ?? "."

        let isRename = line.hasPrefix("2 ")

        let filePath: String
        let oldPath: String?

        if isRename, parts.count >= 9 {
            let pathPart = String(parts[8])
            let pathComponents = pathPart.split(separator: "\t")
            filePath = String(pathComponents.first ?? "")
            oldPath = pathComponents.count > 1 ? String(pathComponents[1]) : nil
        } else {
            filePath = String(parts.last ?? "")
            oldPath = nil
        }

        // Staged changes (index status)
        if indexStatus != "." {
            let kind = statusToChangeKind(indexStatus, isRename: isRename)
            state.stagedChanges.append(GitFileChange(
                path: filePath,
                oldPath: oldPath,
                kind: kind
            ))
        }

        // Unstaged changes (worktree status)
        if workTreeStatus != "." {
            let kind = statusToChangeKind(workTreeStatus, isRename: false)
            state.unstagedChanges.append(GitFileChange(
                path: filePath,
                oldPath: oldPath,
                kind: kind
            ))
        }
    }

    private func statusToChangeKind(_ char: Character, isRename: Bool) -> GitChangeKind {
        if isRename { return .renamed }
        switch char {
        case "M": return .modified
        case "A": return .added
        case "D": return .deleted
        case "R": return .renamed
        case "C": return .copied
        case "T": return .typeChanged
        default: return .modified
        }
    }

    /// Parse unified diff output into a ``GitDiff``.
    private func parseDiff(_ output: String, filePath: String) -> GitDiff {
        var hunks: [DiffHunk] = []
        var currentHeader: String?
        var currentLines: [DiffLine] = []
        var oldLine = 0
        var newLine = 0

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let str = String(line)

            if str.hasPrefix("@@") {
                // Save previous hunk if one exists
                if let header = currentHeader {
                    hunks.append(DiffHunk(header: header, lines: currentLines))
                }
                currentHeader = str
                currentLines = []

                // Parse line numbers from @@ -oldStart,oldCount +newStart,newCount @@
                let parts = str.split(separator: " ")
                if parts.count >= 3 {
                    let oldPart = String(parts[1]).dropFirst()
                    let newPart = String(parts[2]).dropFirst()
                    oldLine = Int(oldPart.split(separator: ",").first ?? "") ?? 0
                    newLine = Int(newPart.split(separator: ",").first ?? "") ?? 0
                }
            } else if currentHeader != nil {
                if str.hasPrefix("+") {
                    currentLines.append(DiffLine(
                        kind: .addition,
                        content: String(str.dropFirst()),
                        oldLineNumber: nil,
                        newLineNumber: newLine
                    ))
                    newLine += 1
                } else if str.hasPrefix("-") {
                    currentLines.append(DiffLine(
                        kind: .deletion,
                        content: String(str.dropFirst()),
                        oldLineNumber: oldLine,
                        newLineNumber: nil
                    ))
                    oldLine += 1
                } else {
                    let content = str.hasPrefix(" ") ? String(str.dropFirst()) : str
                    currentLines.append(DiffLine(
                        kind: .context,
                        content: content,
                        oldLineNumber: oldLine,
                        newLineNumber: newLine
                    ))
                    oldLine += 1
                    newLine += 1
                }
            }
        }

        // Save last hunk
        if let header = currentHeader {
            hunks.append(DiffHunk(header: header, lines: currentLines))
        }

        return GitDiff(filePath: filePath, hunks: hunks)
    }
}
