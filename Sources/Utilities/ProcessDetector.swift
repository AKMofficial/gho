import Foundation

/// Detects what kind of process is running in a terminal session
/// by inspecting child processes of the terminal's shell.
enum ProcessDetector {

    /// Process names recognized as AI coding agents.
    private static let aiAgentNames: Set<String> = [
        "claude", "opencode", "aider", "copilot", "cursor", "windsurf"
    ]

    /// Detect the terminal status based on running child processes.
    static func detectStatus(for session: TerminalSession, using sessionManager: TerminalSessionManager) -> TerminalStatus {
        guard let children = getChildProcessNames(ppid: sessionManager.getShellPID(for: session.id)) else {
            return session.exitCode != nil ? .error : .idle
        }

        if children.isEmpty {
            return .idle
        }

        for child in children {
            let name = child.lowercased()
            if aiAgentNames.contains(where: { name.contains($0) }) {
                return .aiAgent
            }
        }

        return .running
    }

    // MARK: - Private Helpers

    /// Get child process names for a given parent PID in a single `ps` call.
    private static func getChildProcessNames(ppid: Int32?) -> [String]? {
        guard let ppid = ppid, ppid > 0 else { return nil }

        // Use `pgrep -lP <ppid>` to get both PIDs and names in one call.
        // Output format: "<pid> <name>\n" per line.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-lP", "\(ppid)"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output
                .split(separator: "\n")
                .compactMap { line -> String? in
                    // Each line is "<pid> <name>"
                    let parts = line.split(separator: " ", maxSplits: 1)
                    guard parts.count == 2 else { return nil }
                    return String(parts[1]).trimmingCharacters(in: .whitespaces)
                }
        } catch {
            return nil
        }
    }
}
