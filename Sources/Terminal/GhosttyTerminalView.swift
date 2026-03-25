import AppKit
import GhosttyKit
import Metal
import QuartzCore

/// Custom NSView that hosts a libghostty surface with Metal GPU-accelerated rendering.
///
/// Responsibilities:
/// - Sets up a CAMetalLayer for ghostty to render into
/// - Forwards keyboard, mouse, and focus events to the ghostty surface
/// - Handles NSTextInputClient for IME composition
/// - Notifies ghostty of size and content scale changes
final class GhosttyTerminalView: NSView, NSTextInputClient {

    // MARK: - Properties

    /// The ghostty surface this view is bound to. Set after surface creation.
    var surface: ghostty_surface_t? {
        didSet {
            if let surface {
                let scale = window?.backingScaleFactor ?? 2.0
                ghostty_surface_set_content_scale(surface, scale, scale)
                let size = bounds.size
                ghostty_surface_set_size(
                    surface,
                    UInt32(size.width * scale),
                    UInt32(size.height * scale)
                )
            }
        }
    }

    private var metalLayer: CAMetalLayer!
    private var trackingArea: NSTrackingArea?

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true

        guard let device = MTLCreateSystemDefaultDevice() else {
            assertionFailure("Metal is not supported on this device")
            return
        }

        let layer = CAMetalLayer()
        layer.device = device
        layer.pixelFormat = .bgra8Unorm
        layer.framebufferOnly = true
        layer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        layer.isOpaque = true

        self.layer = layer
        self.metalLayer = layer
    }

    // MARK: - Layout

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        metalLayer?.frame = bounds

        guard let surface else { return }
        let scale = window?.backingScaleFactor ?? 2.0
        metalLayer?.contentsScale = scale
        ghostty_surface_set_content_scale(surface, scale, scale)
        ghostty_surface_set_size(
            surface,
            UInt32(newSize.width * scale),
            UInt32(newSize.height * scale)
        )
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        guard let surface, let window else { return }
        let scale = window.backingScaleFactor
        metalLayer?.contentsScale = scale
        ghostty_surface_set_content_scale(surface, scale, scale)
        let size = bounds.size
        ghostty_surface_set_size(
            surface,
            UInt32(size.width * scale),
            UInt32(size.height * scale)
        )
    }

    // MARK: - First Responder

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result, let surface {
            ghostty_surface_set_focus(surface, true)
        }
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result, let surface {
            ghostty_surface_set_focus(surface, false)
        }
        return result
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateTrackingArea()
    }

    // MARK: - Tracking Area (for mouseMoved)

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        updateTrackingArea()
    }

    private func updateTrackingArea() {
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    // MARK: - Keyboard Events

    override func keyDown(with event: NSEvent) {
        guard let surface else { return }

        // Let the input context handle the event for IME support
        interpretKeyEvents([event])

        var input = GhosttyInputTranslator.keyEvent(from: event, action: GHOSTTY_KEY_PRESS)
        if event.isARepeat {
            input.action = GHOSTTY_KEY_REPEAT
        }
        _ = ghostty_surface_key(surface, input)
    }

    override func keyUp(with event: NSEvent) {
        guard let surface else { return }
        let input = GhosttyInputTranslator.keyEvent(from: event, action: GHOSTTY_KEY_RELEASE)
        _ = ghostty_surface_key(surface, input)
    }

    override func flagsChanged(with event: NSEvent) {
        guard let surface else { return }
        // Determine if it is a press or release by checking the modifier flags
        let action: ghostty_input_action_e = event.modifierFlags.contains(
            modifierFlag(for: event.keyCode)
        ) ? GHOSTTY_KEY_PRESS : GHOSTTY_KEY_RELEASE

        let input = GhosttyInputTranslator.keyEvent(from: event, action: action)
        _ = ghostty_surface_key(surface, input)
    }

    /// Map a keyCode to its corresponding NSEvent.ModifierFlags bit.
    private func modifierFlag(for keyCode: UInt16) -> NSEvent.ModifierFlags {
        switch keyCode {
        case 0x38, 0x3C: return .shift
        case 0x3B, 0x3E: return .control
        case 0x3A, 0x3D: return .option
        case 0x37, 0x36: return .command
        case 0x39:       return .capsLock
        case 0x3F:       return .function
        default:         return []
        }
    }

    // MARK: - Mouse Events

    /// Send the current mouse position (in view-local, flipped coordinates) to the surface.
    private func sendMousePos(from event: NSEvent, surface: ghostty_surface_t, mods: ghostty_input_mods_e) {
        let pos = convert(event.locationInWindow, from: nil)
        ghostty_surface_mouse_pos(surface, pos.x, bounds.height - pos.y, mods)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        guard let surface else { return }
        let mods = GhosttyInputTranslator.modifiers(from: event.modifierFlags)
        sendMousePos(from: event, surface: surface, mods: mods)
        _ = ghostty_surface_mouse_button(
            surface, GHOSTTY_MOUSE_PRESS, GHOSTTY_MOUSE_BUTTON_LEFT, mods
        )
    }

    override func mouseUp(with event: NSEvent) {
        guard let surface else { return }
        let mods = GhosttyInputTranslator.modifiers(from: event.modifierFlags)
        _ = ghostty_surface_mouse_button(
            surface, GHOSTTY_MOUSE_RELEASE, GHOSTTY_MOUSE_BUTTON_LEFT, mods
        )
    }

    override func mouseMoved(with event: NSEvent) {
        guard let surface else { return }
        let mods = GhosttyInputTranslator.modifiers(from: event.modifierFlags)
        sendMousePos(from: event, surface: surface, mods: mods)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let surface else { return }
        let mods = GhosttyInputTranslator.modifiers(from: event.modifierFlags)
        sendMousePos(from: event, surface: surface, mods: mods)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let surface else { return }
        let mods = GhosttyInputTranslator.modifiers(from: event.modifierFlags)
        sendMousePos(from: event, surface: surface, mods: mods)
        _ = ghostty_surface_mouse_button(
            surface, GHOSTTY_MOUSE_PRESS, GHOSTTY_MOUSE_BUTTON_RIGHT, mods
        )
    }

    override func rightMouseUp(with event: NSEvent) {
        guard let surface else { return }
        let mods = GhosttyInputTranslator.modifiers(from: event.modifierFlags)
        _ = ghostty_surface_mouse_button(
            surface, GHOSTTY_MOUSE_RELEASE, GHOSTTY_MOUSE_BUTTON_RIGHT, mods
        )
    }

    override func scrollWheel(with event: NSEvent) {
        guard let surface else { return }
        let mods = GhosttyInputTranslator.modifiers(from: event.modifierFlags)
        let momentum = GhosttyInputTranslator.scrollMomentum(from: event)
        ghostty_surface_mouse_scroll(
            surface,
            event.scrollingDeltaX,
            event.scrollingDeltaY,
            mods,
            momentum
        )
    }

    // MARK: - NSTextInputClient (IME support)

    func insertText(_ string: Any, replacementRange: NSRange) {
        guard let surface else { return }
        let text: String
        if let s = string as? String {
            text = s
        } else if let attr = string as? NSAttributedString {
            text = attr.string
        } else {
            return
        }

        text.withCString { ptr in
            ghostty_surface_text(surface, ptr, text.utf8.count)
        }
    }

    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        // Marked text (IME composition) — libghostty handles this internally
    }

    func unmarkText() {
        // End of IME composition
    }

    func selectedRange() -> NSRange {
        NSRange(location: NSNotFound, length: 0)
    }

    func markedRange() -> NSRange {
        NSRange(location: NSNotFound, length: 0)
    }

    func hasMarkedText() -> Bool {
        false
    }

    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        nil
    }

    func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        []
    }

    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        // Return cursor position for IME candidate window placement
        guard let window else { return .zero }
        let viewRect = NSRect(x: 0, y: 0, width: 0, height: 0)
        let windowRect = convert(viewRect, to: nil)
        return window.convertToScreen(windowRect)
    }

    func characterIndex(for point: NSPoint) -> Int {
        0
    }
}
