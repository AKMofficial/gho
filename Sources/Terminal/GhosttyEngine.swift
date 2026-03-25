import AppKit
import GhosttyKit
import SwiftUI

/// Concrete implementation of ``TerminalEngineProtocol`` backed by
/// libghostty's Metal-accelerated terminal engine.
///
/// Each instance manages a single ghostty surface and its associated
/// ``GhosttyTerminalView``. The surface is created once both the NSView
/// and the shell process parameters are available (deferred creation pattern).
final class GhosttyEngine: TerminalEngineProtocol {

    // MARK: - TerminalEngineProtocol Properties

    let terminalID: UUID
    weak var delegate: TerminalEngineDelegate?

    var isRunning: Bool {
        surface != nil
    }

    private(set) var processStarted = false

    var shellPid: Int32? {
        guard let pid = reportedPid, pid > 0 else { return nil }
        return pid
    }

    // MARK: - Internal State (accessed by GhosttyAppController callbacks)

    /// PID reported by libghostty via the REPORT_CHILD_PID action.
    var reportedPid: Int32?

    /// The ghostty surface handle, nil until both view and process are ready.
    private(set) var surface: ghostty_surface_t?

    // MARK: - Private State

    private var terminalView: GhosttyTerminalView?

    /// Deferred process parameters — stored by startProcess(), consumed
    /// by createSurface() once the view is also available.
    private var pendingShell: String?
    private var pendingWorkingDirectory: URL?

    // MARK: - Init

    init(terminalID: UUID) {
        self.terminalID = terminalID
    }

    // MARK: - TerminalEngineProtocol — View Lifecycle

    func makeView() -> NSView {
        if let existing = terminalView {
            return existing
        }

        let view = GhosttyTerminalView(
            frame: NSRect(x: 0, y: 0, width: 800, height: 600)
        )
        self.terminalView = view

        // If startProcess was already called, we can now create the surface
        if processStarted {
            createSurface()
        }

        return view
    }

    // MARK: - TerminalEngineProtocol — Process

    func startProcess(
        shell: String,
        arguments: [String],
        environment: [String: String],
        workingDirectory: URL
    ) {
        processStarted = true
        pendingShell = shell
        pendingWorkingDirectory = workingDirectory

        // If makeView was already called, we can now create the surface
        if terminalView != nil {
            createSurface()
        }
    }

    func terminate() {
        if let surface {
            GhosttyAppController.shared.unregister(surface: surface)
            ghostty_surface_free(surface)
        }
        surface = nil
        terminalView?.surface = nil
        terminalView = nil
        reportedPid = nil
    }

    // MARK: - TerminalEngineProtocol — I/O

    func send(data: Data) {
        guard let surface else { return }
        data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            let ptr = baseAddress.assumingMemoryBound(to: CChar.self)
            ghostty_surface_text(surface, ptr, data.count)
        }
    }

    func send(text: String) {
        guard let surface else { return }
        text.withCString { ptr in
            ghostty_surface_text(surface, ptr, text.utf8.count)
        }
    }

    // MARK: - TerminalEngineProtocol — Display

    func resize(cols: Int, rows: Int) {
        // No-op: ghostty handles resize automatically when the NSView frame
        // changes via GhosttyTerminalView.setFrameSize → ghostty_surface_set_size.
    }

    func setFont(name: String, size: CGFloat) {
        guard let app = GhosttyAppController.shared.app else { return }
        var settings: [(key: String, value: String)] = []
        settings.append((key: "font-family", value: name))
        settings.append((key: "font-size", value: String(Int(size))))
        guard let cfg = GhosttyAppController.shared.makeConfig(settings: settings) else { return }
        ghostty_app_update_config(app, cfg)
        ghostty_config_free(cfg)
    }

    func setColors(foreground: NSColor, background: NSColor) {
        guard let app = GhosttyAppController.shared.app else { return }
        let fgHex = foreground.hexString
        let bgHex = background.hexString
        var settings: [(key: String, value: String)] = []
        settings.append((key: "foreground", value: fgHex))
        settings.append((key: "background", value: bgHex))
        guard let cfg = GhosttyAppController.shared.makeConfig(settings: settings) else { return }
        ghostty_app_update_config(app, cfg)
        ghostty_config_free(cfg)
    }

    // MARK: - TerminalEngineProtocol — Selection & Search

    func getSelection() -> String? {
        return GhosttyAppController.shared.lastClipboardContent
    }

    func selectAll() {
        // Send synthetic Cmd+A key event
        guard let surface else { return }
        var input = ghostty_input_key_s()
        input.action = GHOSTTY_KEY_PRESS
        input.mods = ghostty_input_mods_e(rawValue: UInt32(GHOSTTY_MOD_SUPER.rawValue))
        input.consumed_mods = GHOSTTY_MOD_NONE
        input.keycode = 0x00 // A key
        input.text = nil
        input.text_len = 0
        input.unshifted_codepoint = 0x61 // 'a'
        input.composing = false
        _ = ghostty_surface_key(surface, input)
    }

    func clearSelection() {
        // Send synthetic Escape key event to clear selection
        guard let surface else { return }
        var input = ghostty_input_key_s()
        input.action = GHOSTTY_KEY_PRESS
        input.mods = GHOSTTY_MOD_NONE
        input.consumed_mods = GHOSTTY_MOD_NONE
        input.keycode = 0x35 // Escape key
        input.text = nil
        input.text_len = 0
        input.unshifted_codepoint = 0x1B // ESC
        input.composing = false
        _ = ghostty_surface_key(surface, input)
        GhosttyAppController.shared.lastClipboardContent = nil
    }

    func scrollToBottom() {
        // Send synthetic End key event
        guard let surface else { return }
        var input = ghostty_input_key_s()
        input.action = GHOSTTY_KEY_PRESS
        input.mods = GHOSTTY_MOD_NONE
        input.consumed_mods = GHOSTTY_MOD_NONE
        input.keycode = 0x77 // End key
        input.text = nil
        input.text_len = 0
        input.unshifted_codepoint = 0
        input.composing = false
        _ = ghostty_surface_key(surface, input)
    }

    func search(query: String) -> Int {
        // Search is not yet supported via libghostty's public API; return 0.
        return 0
    }

    // MARK: - Surface Creation

    /// Creates the ghostty surface once both the NSView and process parameters
    /// are available.
    ///
    /// This implements the "deferred creation" pattern: ``makeView()`` and
    /// ``startProcess()`` each store their data, and whichever runs second
    /// triggers this method.
    private func createSurface() {
        guard let app = GhosttyAppController.shared.app,
              let view = terminalView,
              let shell = pendingShell,
              let workDir = pendingWorkingDirectory else {
            return
        }

        // Already created?
        guard surface == nil else { return }

        let scale = view.window?.backingScaleFactor ?? 2.0
        let viewPtr = Unmanaged.passUnretained(view).toOpaque()

        var surfaceConfig = ghostty_surface_config_s()
        surfaceConfig.platform_tag = GHOSTTY_PLATFORM_MACOS
        surfaceConfig.platform.macos.nsview = viewPtr
        surfaceConfig.platform.macos.display_id = CGMainDisplayID()
        surfaceConfig.userdata = Unmanaged.passUnretained(self).toOpaque()
        surfaceConfig.scale_factor = scale
        surfaceConfig.font_size = 13.0
        surfaceConfig.context = GHOSTTY_SURFACE_CONTEXT_SPLIT

        // withCString ensures pointer lifetime spans the ghostty_surface_new call
        shell.withCString { cmdPtr in
            workDir.path.withCString { wdPtr in
                surfaceConfig.command = cmdPtr
                surfaceConfig.working_directory = wdPtr
                self.surface = ghostty_surface_new(app, &surfaceConfig)
            }
        }

        if let surface {
            view.surface = surface
            GhosttyAppController.shared.register(surface: surface, engine: self)
            ghostty_surface_set_focus(surface, true)
        }

        // Clear pending data
        pendingShell = nil
        pendingWorkingDirectory = nil
    }
}

// MARK: - NSColor Hex Helper

private extension NSColor {
    /// Returns a hex string like "#rrggbb" from the color, converting to sRGB first.
    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#ffffff" }
        let r = Int(rgb.redComponent * 255)
        let g = Int(rgb.greenComponent * 255)
        let b = Int(rgb.blueComponent * 255)
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}

// MARK: - SwiftUI NSViewRepresentable Wrapper

/// An `NSViewRepresentable` bridge that hosts a ``GhosttyEngine``'s
/// terminal view inside SwiftUI.
///
/// The engine owns the `NSView` and manages all updates (surface lifecycle,
/// input routing, etc.). This wrapper simply provides the hosting container
/// and ensures the view fills the available space.
struct GhosttyNSViewWrapper: NSViewRepresentable {

    /// The engine whose terminal view should be displayed.
    let engine: GhosttyEngine

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> NSView {
        let terminalNSView = engine.makeView()
        terminalNSView.autoresizingMask = [.width, .height]
        return terminalNSView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // The engine owns all view configuration.
        // No updates are driven from the SwiftUI side.
    }
}
