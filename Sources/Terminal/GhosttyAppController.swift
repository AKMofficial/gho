import AppKit
import GhosttyKit

/// Singleton that manages the global ghostty_app_t lifecycle.
///
/// Responsible for:
/// - Creating and destroying the libghostty application instance
/// - Running the tick loop (at ~120 Hz) so libghostty processes I/O
/// - Routing C callbacks from libghostty back to the correct ``GhosttyEngine``
final class GhosttyAppController {

    // MARK: - Singleton

    static let shared = GhosttyAppController()

    // MARK: - State

    private(set) var app: ghostty_app_t?
    private var config: ghostty_config_t?
    private var tickTimer: DispatchSourceTimer?

    /// Maps a ghostty surface pointer to its owning engine so that
    /// C callbacks can look up the correct Swift object.
    private var surfaceToEngine: [UnsafeRawPointer: GhosttyEngine] = [:]

    /// Last clipboard content written by any surface, used by
    /// ``GhosttyEngine/getSelection()`` when the specific surface is unknown.
    var lastClipboardContent: String?

    private init() {}

    // MARK: - Lifecycle

    /// Initialize the libghostty runtime and create the application instance.
    ///
    /// Must be called once on the main thread before any surfaces are created.
    func initialize() {
        guard app == nil else { return }

        // Global init
        ghostty_init(0, nil)

        // Create base config
        let cfg = ghostty_config_new()!
        ghostty_config_load_default_files(cfg)
        ghostty_config_finalize(cfg)
        self.config = cfg

        // Set up runtime callbacks
        var runtime = ghostty_runtime_config_s()
        runtime.userdata = Unmanaged.passUnretained(self).toOpaque()
        runtime.supports_selection_clipboard = false
        runtime.wakeup_cb = ghosttyWakeupCallback
        runtime.action_cb = ghosttyActionCallback
        runtime.read_clipboard_cb = ghosttyReadClipboardCallback
        runtime.confirm_read_clipboard_cb = nil
        runtime.write_clipboard_cb = ghosttyWriteClipboardCallback
        runtime.close_surface_cb = nil

        self.app = ghostty_app_new(&runtime, cfg)

        startTickLoop()
    }

    /// Shut down the libghostty application, stopping the tick loop and
    /// freeing all resources.
    func shutdown() {
        stopTickLoop()

        if let app {
            ghostty_app_free(app)
        }
        app = nil

        if let config {
            ghostty_config_free(config)
        }
        config = nil

        surfaceToEngine.removeAll()
    }

    // MARK: - Surface Registration

    /// Register a surface → engine mapping so callbacks can be routed.
    func register(surface: ghostty_surface_t, engine: GhosttyEngine) {
        let key = UnsafeRawPointer(surface)
        surfaceToEngine[key] = engine
    }

    /// Remove the mapping for a surface that is being torn down.
    func unregister(surface: ghostty_surface_t) {
        let key = UnsafeRawPointer(surface)
        surfaceToEngine.removeValue(forKey: key)
    }

    /// Look up the engine for a given surface pointer.
    func engine(for surface: ghostty_surface_t) -> GhosttyEngine? {
        let key = UnsafeRawPointer(surface)
        return surfaceToEngine[key]
    }

    /// Find the first engine whose surface is non-nil (used for clipboard requests
    /// where libghostty does not identify which surface initiated the request).
    func firstActiveSurface() -> (surface: ghostty_surface_t, engine: GhosttyEngine)? {
        for (_, engine) in surfaceToEngine {
            if let surface = engine.surface {
                return (surface, engine)
            }
        }
        return nil
    }

    /// Apply a closure to the engine that owns a given surface (used by clipboard write callback).
    func withEngine(for surface: ghostty_surface_t, _ body: (GhosttyEngine) -> Void) {
        if let engine = engine(for: surface) {
            body(engine)
        }
    }

    // MARK: - Config Helpers

    /// Create a new ghostty config, apply key/value pairs, and finalize it.
    func makeConfig(settings: [(key: String, value: String)]) -> ghostty_config_t? {
        guard let cfg = ghostty_config_new() else { return nil }
        for setting in settings {
            setting.key.withCString { keyPtr in
                setting.value.withCString { valPtr in
                    _ = ghostty_config_set(
                        cfg, keyPtr, setting.key.utf8.count,
                        valPtr, setting.value.utf8.count
                    )
                }
            }
        }
        ghostty_config_finalize(cfg)
        return cfg
    }

    // MARK: - Tick Loop

    private func startTickLoop() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(
            deadline: .now(),
            repeating: .milliseconds(8) // ~120 Hz
        )
        timer.setEventHandler { [weak self] in
            guard let app = self?.app else { return }
            ghostty_app_tick(app)
        }
        timer.resume()
        tickTimer = timer
    }

    private func stopTickLoop() {
        tickTimer?.cancel()
        tickTimer = nil
    }
}

// MARK: - C Callbacks (top-level @convention(c) functions)

/// Called by libghostty when it needs the main thread to wake up and tick.
private func ghosttyWakeupCallback(userdata: UnsafeMutableRawPointer?) {
    DispatchQueue.main.async {
        guard let app = GhosttyAppController.shared.app else { return }
        ghostty_app_tick(app)
    }
}

/// Called by libghostty for all actions (title changes, directory changes,
/// process exits, clipboard writes, etc.).
private func ghosttyActionCallback(
    app: ghostty_app_t?,
    target: ghostty_target_s,
    action: ghostty_action_s,
    userdata: UnsafeMutableRawPointer?
) -> Bool {
    let controller = GhosttyAppController.shared

    // Only handle surface-targeted actions
    guard target.is_surface, let surface = target.surface else {
        return false
    }

    guard let engine = controller.engine(for: surface) else {
        return false
    }

    switch action.tag {
    case GHOSTTY_ACTION_SET_TITLE:
        let titleData = action.action.set_title
        if let ptr = titleData.title, titleData.title_len > 0 {
            let rawBuf = UnsafeRawBufferPointer(start: ptr, count: titleData.title_len)
            let title = String(decoding: rawBuf, as: UTF8.self)
            DispatchQueue.main.async {
                engine.delegate?.terminalDidUpdateTitle(engine, title: title)
            }
        }
        return true

    case GHOSTTY_ACTION_SET_WORKING_DIRECTORY:
        let dirData = action.action.set_working_directory
        if let ptr = dirData.path, dirData.path_len > 0 {
            let rawBuf = UnsafeRawBufferPointer(start: ptr, count: dirData.path_len)
            let path = String(decoding: rawBuf, as: UTF8.self)
            let url = URL(fileURLWithPath: path)
            DispatchQueue.main.async {
                engine.delegate?.terminalDidChangeDirectory(engine, directory: url)
            }
        }
        return true

    case GHOSTTY_ACTION_REPORT_CHILD_PID:
        let pid = action.action.child_pid.pid
        DispatchQueue.main.async {
            engine.reportedPid = pid
        }
        return true

    case GHOSTTY_ACTION_CLOSE_SURFACE:
        let exitCode = action.action.close_surface
        DispatchQueue.main.async {
            engine.delegate?.terminalProcessDidExit(engine, exitCode: exitCode)
        }
        return true

    case GHOSTTY_ACTION_COPY_TO_CLIPBOARD:
        // Handled by the write clipboard callback instead
        return false

    case GHOSTTY_ACTION_PASTE_FROM_CLIPBOARD:
        return false

    default:
        return false
    }
}

/// Called by libghostty when it wants to read from the system clipboard.
private func ghosttyReadClipboardCallback(
    userdata: UnsafeMutableRawPointer?,
    clipboardType: ghostty_clipboard_e,
    context: UnsafeMutableRawPointer?
) {
    DispatchQueue.main.async {
        let pasteboard = NSPasteboard.general
        let content = pasteboard.string(forType: .string) ?? ""

        guard let (surface, _) = GhosttyAppController.shared.firstActiveSurface() else { return }
        content.withCString { ptr in
            ghostty_surface_complete_clipboard_request(
                surface, ptr, content.utf8.count, context
            )
        }
    }
}

/// Called by libghostty when the terminal wants to write to the clipboard.
private func ghosttyWriteClipboardCallback(
    userdata: UnsafeMutableRawPointer?,
    clipboardType: ghostty_clipboard_e,
    content: UnsafePointer<ghostty_clipboard_content_s>?,
    count: Int,
    clear: Bool
) {
    guard let content, count > 0 else { return }

    DispatchQueue.main.async {
        let pasteboard = NSPasteboard.general
        if clear {
            pasteboard.clearContents()
        }

        for i in 0..<count {
            let item = content[i]
            if let dataPtr = item.data, item.len > 0 {
                let rawBuf = UnsafeRawBufferPointer(start: dataPtr, count: item.len)
                let str = String(decoding: rawBuf, as: UTF8.self)
                pasteboard.clearContents()
                pasteboard.setString(str, forType: .string)
                GhosttyAppController.shared.lastClipboardContent = str
            }
        }
    }
}
