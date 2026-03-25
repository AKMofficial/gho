import Foundation

// MARK: - Supporting Types

struct GitDiff {
    let filePath: String
    let hunks: [DiffHunk]
}

struct DiffHunk {
    let header: String
    let lines: [DiffLine]
}

struct DiffLine {
    enum Kind {
        case context
        case addition
        case deletion
    }

    let kind: Kind
    let content: String
    let oldLineNumber: Int?
    let newLineNumber: Int?
}

enum GitError: Error, LocalizedError {
    case commandFailed(String)
    case notARepository

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return "Git command failed: \(message)"
        case .notARepository:
            return "Not a git repository"
        }
    }
}

// MARK: - Protocol

protocol GitServiceProtocol: Sendable {
    func isGitRepository(at path: URL) async -> Bool
    func getStatus(at path: URL) async throws -> GitState
    func getBranches(at path: URL) async throws -> [String]
    func currentBranch(at path: URL) async throws -> String
    func switchBranch(at path: URL, to branch: String) async throws
    func createBranch(at path: URL, name: String) async throws
    func stage(file: String, at path: URL) async throws
    func unstage(file: String, at path: URL) async throws
    func stageAll(at path: URL) async throws
    func unstageAll(at path: URL) async throws
    func discardChanges(file: String, at path: URL) async throws
    func diff(file: String, staged: Bool, at path: URL) async throws -> GitDiff
    func commit(message: String, at path: URL) async throws
    func push(at path: URL) async throws
    func pull(at path: URL) async throws
    func stash(at path: URL, message: String?) async throws
    func stashPop(at path: URL) async throws
    func stashList(at path: URL) async throws -> [String]
    func createPR(title: String, body: String, baseBranch: String, at path: URL) async throws -> URL
}
