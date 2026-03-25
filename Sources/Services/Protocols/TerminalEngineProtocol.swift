import AppKit

protocol TerminalEngineDelegate: AnyObject {
    func terminalDidUpdateTitle(_ engine: any TerminalEngineProtocol, title: String)
    func terminalDidChangeDirectory(_ engine: any TerminalEngineProtocol, directory: URL)
    func terminalProcessDidExit(_ engine: any TerminalEngineProtocol, exitCode: Int32?)
    func terminalDidReceiveData(_ engine: any TerminalEngineProtocol)
}

protocol TerminalEngineProtocol: AnyObject {
    var delegate: TerminalEngineDelegate? { get set }
    var terminalID: UUID { get }
    var isRunning: Bool { get }
    var processStarted: Bool { get }
    var shellPid: Int32? { get }

    func makeView() -> NSView
    func startProcess(shell: String, arguments: [String], environment: [String: String], workingDirectory: URL)
    func send(data: Data)
    func send(text: String)
    func resize(cols: Int, rows: Int)
    func getSelection() -> String?
    func selectAll()
    func clearSelection()
    func scrollToBottom()
    func search(query: String) -> Int
    func setFont(name: String, size: CGFloat)
    func setColors(foreground: NSColor, background: NSColor)
    func terminate()
}
