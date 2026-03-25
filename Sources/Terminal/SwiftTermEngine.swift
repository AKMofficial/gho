import AppKit
import SwiftTerm

/// Default terminal background color (#1a1a1a).
/// Shared across the engine and placeholder views to avoid literal duplication.
let terminalBackgroundNSColor = NSColor(
    red: 0.102, green: 0.102, blue: 0.102, alpha: 1.0
)

/// Concrete implementation of ``TerminalEngineProtocol`` backed by
/// SwiftTerm's `LocalProcessTerminalView`.
///
/// Each instance manages a single terminal view and its associated PTY
/// process. The engine is created early (when a session is opened) but the
/// underlying `NSView` is only materialised when ``makeView()`` is called.
final class SwiftTermEngine: NSObject, TerminalEngineProtocol {

    // MARK: - TerminalEngineProtocol Properties

    let terminalID: UUID
    weak var delegate: TerminalEngineDelegate?

    var isRunning: Bool {
        terminalView != nil
    }

    // MARK: - Private State

    private var terminalView: LocalProcessTerminalView?

    // MARK: - Init

    init(terminalID: UUID) {
        self.terminalID = terminalID
        super.init()
    }

    // MARK: - TerminalEngineProtocol — View Lifecycle

    func makeView() -> NSView {
        if let existing = terminalView {
            return existing
        }

        let view = LocalProcessTerminalView(
            frame: NSRect(x: 0, y: 0, width: 800, height: 600)
        )

        // Default appearance
        view.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        view.nativeBackgroundColor = terminalBackgroundNSColor
        view.nativeForegroundColor = NSColor.white

        // Wire delegate for process callbacks
        view.processDelegate = self

        self.terminalView = view
        return view
    }

    // MARK: - TerminalEngineProtocol — Process

    func startProcess(
        shell: String,
        arguments: [String],
        environment: [String: String],
        workingDirectory: URL
    ) {
        let envArray = environment.map { "\($0.key)=\($0.value)" }
        terminalView?.startProcess(
            executable: shell,
            args: arguments,
            environment: envArray,
            execName: nil
        )
    }

    func terminate() {
        // Send SIGHUP to the child process if still running
        if let view = terminalView {
            let pid = view.process?.shellPid ?? 0
            if pid > 0 {
                kill(pid, SIGHUP)
            }
        }
        terminalView = nil
    }

    // MARK: - TerminalEngineProtocol — I/O

    func send(data: Data) {
        let bytes = [UInt8](data)
        terminalView?.send(bytes)
    }

    func send(text: String) {
        terminalView?.send(txt: text)
    }

    // MARK: - TerminalEngineProtocol — Display

    func resize(cols: Int, rows: Int) {
        // SwiftTerm handles resize automatically when the NSView resizes,
        // but we can manually request it via the terminal.
        terminalView?.getTerminal().resize(cols: cols, rows: rows)
    }

    func setFont(name: String, size: CGFloat) {
        if let font = NSFont(name: name, size: size) {
            terminalView?.font = font
        } else {
            // Fall back to system monospace at the requested size
            terminalView?.font = NSFont.monospacedSystemFont(
                ofSize: size, weight: .regular
            )
        }
    }

    func setColors(foreground: NSColor, background: NSColor) {
        terminalView?.nativeForegroundColor = foreground
        terminalView?.nativeBackgroundColor = background
    }

    // MARK: - TerminalEngineProtocol — Selection & Search

    func getSelection() -> String? {
        return terminalView?.getSelection()
    }

    func selectAll() {
        terminalView?.selectAll(nil)
    }

    func clearSelection() {
        terminalView?.selectNone()
    }

    func scrollToBottom() {
        terminalView?.scroll(toPosition: 1.0)
    }

    func search(query: String) -> Int {
        guard terminalView != nil else { return 0 }
        // SwiftTerm's search API is limited; return 0 for now.
        // Full search can be implemented via getTerminal().getBufferAsString()
        return 0
    }
}

// MARK: - LocalProcessTerminalViewDelegate

extension SwiftTermEngine: LocalProcessTerminalViewDelegate {

    func sizeChanged(
        source: LocalProcessTerminalView,
        newCols: Int,
        newRows: Int
    ) {
        // The terminal was resized — no action needed from the engine;
        // SwiftTerm already applied the resize to the PTY.
    }

    func setTerminalTitle(
        source: LocalProcessTerminalView,
        title: String
    ) {
        delegate?.terminalDidUpdateTitle(self, title: title)
    }

    func hostCurrentDirectoryUpdate(
        source: TerminalView,
        directory: String?
    ) {
        if let dir = directory {
            delegate?.terminalDidChangeDirectory(
                self,
                directory: URL(fileURLWithPath: dir)
            )
        }
    }

    func processTerminated(
        source: TerminalView,
        exitCode: Int32?
    ) {
        delegate?.terminalProcessDidExit(self, exitCode: exitCode)
    }
}
