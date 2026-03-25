import AppKit
import Foundation

/// Manages the lifecycle of terminal sessions and their backing engines.
///
/// `TerminalSessionManager` is the single source of truth for engine
/// instances. It creates ``SwiftTermEngine`` objects, wires their delegates,
/// starts shell processes, and tears everything down on close.
///
/// Injected into the SwiftUI environment so that views can look up engines
/// by terminal ID.
@Observable
final class TerminalSessionManager: TerminalEngineDelegate {

    // MARK: - State

    /// Map of terminal-session ID to its engine.
    private var engines: [UUID: any TerminalEngineProtocol] = [:]

    /// Reference to the shared app state (provided at init).
    private let appState: AppState

    /// Tracks when process detection last ran per terminal, to throttle
    /// expensive external-process spawning on the hot data-receive path.
    private var lastDetectionTime: [UUID: ContinuousClock.Instant] = [:]

    /// Minimum interval between process-detection checks for a given terminal.
    private let detectionThrottleInterval: ContinuousClock.Duration = .seconds(2)

    // MARK: - Init

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Public API

    /// Create a new ``TerminalSession`` together with its engine.
    ///
    /// The session is *not* added to any ``PathGroup`` here — that is the
    /// caller's responsibility (typically via `AppState.addTerminal`).
    @discardableResult
    func createSession(
        in group: PathGroup,
        label: String? = nil
    ) -> TerminalSession {
        let session = TerminalSession(
            id: UUID(),
            label: label ?? "Terminal \(group.terminals.count + 1)",
            workingDirectory: group.path,
            pathGroupID: group.id
        )

        let engine = SwiftTermEngine(terminalID: session.id)
        engine.delegate = self
        engines[session.id] = engine

        return session
    }

    /// Start the shell process for a session.
    ///
    /// Must be called **after** the view has been created via ``makeView()``
    /// so that the underlying `LocalProcessTerminalView` exists.
    func startProcess(for sessionID: UUID) {
        guard let engine = engines[sessionID] else { return }

        let settings = appState.settings

        // Build environment from the current process
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        if env["LANG"] == nil {
            env["LANG"] = "en_US.UTF-8"
        }

        // Determine working directory
        let workDir: URL
        if let session = findSession(id: sessionID) {
            workDir = session.workingDirectory
        } else {
            workDir = URL(fileURLWithPath: NSHomeDirectory())
        }

        engine.startProcess(
            shell: settings.defaultShell,
            arguments: ["-l"], // login shell
            environment: env,
            workingDirectory: workDir
        )
    }

    /// Retrieve the engine for a given terminal ID.
    func engine(for terminalID: UUID) -> (any TerminalEngineProtocol)? {
        engines[terminalID]
    }

    /// Tear down a session's engine and clean up resources.
    func destroySession(id: UUID) {
        engines[id]?.terminate()
        engines.removeValue(forKey: id)
        lastDetectionTime.removeValue(forKey: id)
    }

    /// Apply the current ``AppSettings`` (font family, size) to every engine.
    func applySettings() {
        let settings = appState.settings
        for engine in engines.values {
            engine.setFont(
                name: settings.terminalFontFamily,
                size: settings.terminalFontSize
            )
        }
    }

    // MARK: - TerminalEngineDelegate

    func terminalDidUpdateTitle(
        _ engine: any TerminalEngineProtocol,
        title: String
    ) {
        if let session = findSession(id: engine.terminalID) {
            session.label = title
        }
    }

    func terminalDidChangeDirectory(
        _ engine: any TerminalEngineProtocol,
        directory: URL
    ) {
        if let session = findSession(id: engine.terminalID) {
            session.workingDirectory = directory
        }
    }

    func terminalProcessDidExit(
        _ engine: any TerminalEngineProtocol,
        exitCode: Int32?
    ) {
        if let session = findSession(id: engine.terminalID) {
            session.exitCode = exitCode
            session.status = (exitCode == 0 || exitCode == nil) ? .idle : .error
        }
    }

    func terminalDidReceiveData(_ engine: any TerminalEngineProtocol) {
        let id = engine.terminalID
        let now = ContinuousClock.now

        // Throttle: skip if we checked recently for this terminal
        if let last = lastDetectionTime[id],
           now - last < detectionThrottleInterval {
            return
        }
        lastDetectionTime[id] = now

        if let session = findSession(id: id) {
            Task { @MainActor in
                let newStatus = ProcessDetector.detectStatus(for: session)
                if session.status != newStatus {
                    session.status = newStatus
                }
            }
        }
    }

    // MARK: - Private Helpers

    /// Look up a ``TerminalSession`` by ID across all path groups.
    private func findSession(id: UUID) -> TerminalSession? {
        for group in appState.pathGroups {
            if let session = group.terminals.first(where: { $0.id == id }) {
                return session
            }
        }
        return nil
    }
}
