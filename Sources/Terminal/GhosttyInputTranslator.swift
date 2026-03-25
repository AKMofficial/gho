import AppKit
import GhosttyKit

/// Translates macOS NSEvent objects into libghostty input structures.
///
/// All methods are static — no instance state is needed.
enum GhosttyInputTranslator {

    // MARK: - Keyboard

    /// Convert an NSEvent key event into a ghostty key input struct.
    ///
    /// macOS virtual key codes are passed through directly since ghostty
    /// uses the same values.
    static func keyEvent(from event: NSEvent, action: ghostty_input_action_e) -> ghostty_input_key_s {
        let mods = modifiers(from: event.modifierFlags)

        var input = ghostty_input_key_s()
        input.action = action
        input.mods = mods
        input.consumed_mods = GHOSTTY_MOD_NONE
        input.keycode = UInt32(event.keyCode)
        input.text = nil
        input.text_len = 0
        input.unshifted_codepoint = 0
        input.composing = false

        // For key press/repeat, attach the text if available
        if action == GHOSTTY_KEY_PRESS || action == GHOSTTY_KEY_REPEAT {
            if let chars = event.characters, !chars.isEmpty {
                // unshifted_codepoint from charactersIgnoringModifiers
                if let unshifted = event.charactersIgnoringModifiers?.unicodeScalars.first {
                    input.unshifted_codepoint = unshifted.value
                }
            }
        }

        return input
    }

    /// Convert NSEvent modifier flags to ghostty modifier flags.
    static func modifiers(from flags: NSEvent.ModifierFlags) -> ghostty_input_mods_e {
        var mods: UInt32 = 0
        if flags.contains(.shift)   { mods |= UInt32(GHOSTTY_MOD_SHIFT.rawValue) }
        if flags.contains(.control) { mods |= UInt32(GHOSTTY_MOD_CTRL.rawValue) }
        if flags.contains(.option)  { mods |= UInt32(GHOSTTY_MOD_ALT.rawValue) }
        if flags.contains(.command) { mods |= UInt32(GHOSTTY_MOD_SUPER.rawValue) }
        if flags.contains(.capsLock) { mods |= UInt32(GHOSTTY_MOD_CAPS.rawValue) }
        if flags.contains(.numericPad) { mods |= UInt32(GHOSTTY_MOD_NUM.rawValue) }
        return ghostty_input_mods_e(rawValue: mods)
    }

    // MARK: - Mouse

    /// Convert a mouse button NSEvent to a ghostty mouse button.
    static func mouseButton(from event: NSEvent) -> ghostty_input_mouse_button_e {
        switch event.buttonNumber {
        case 0: return GHOSTTY_MOUSE_BUTTON_LEFT
        case 1: return GHOSTTY_MOUSE_BUTTON_RIGHT
        case 2: return GHOSTTY_MOUSE_BUTTON_MIDDLE
        case 3: return GHOSTTY_MOUSE_BUTTON_FOUR
        case 4: return GHOSTTY_MOUSE_BUTTON_FIVE
        default: return GHOSTTY_MOUSE_BUTTON_LEFT
        }
    }

    /// Convert a scroll event's momentum phase to ghostty momentum enum.
    static func scrollMomentum(from event: NSEvent) -> ghostty_input_mouse_momentum_e {
        switch event.momentumPhase {
        case .began:      return GHOSTTY_MOUSE_MOMENTUM_BEGAN
        case .stationary: return GHOSTTY_MOUSE_MOMENTUM_STATIONARY
        case .changed:    return GHOSTTY_MOUSE_MOMENTUM_CHANGED
        case .ended:      return GHOSTTY_MOUSE_MOMENTUM_ENDED
        case .cancelled:  return GHOSTTY_MOUSE_MOMENTUM_CANCELLED
        case .mayBegin:   return GHOSTTY_MOUSE_MOMENTUM_MAY_BEGIN
        default:          return GHOSTTY_MOUSE_MOMENTUM_NONE
        }
    }

}
