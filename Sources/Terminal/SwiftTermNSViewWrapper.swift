import AppKit
import SwiftUI

/// An `NSViewRepresentable` bridge that hosts a ``SwiftTermEngine``'s
/// terminal view inside SwiftUI.
///
/// The engine owns the `NSView` and manages all updates (font, colors,
/// process lifecycle). This wrapper simply provides the hosting container
/// and ensures the view fills the available space.
struct SwiftTermNSViewWrapper: NSViewRepresentable {

    /// The engine whose terminal view should be displayed.
    let engine: SwiftTermEngine

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> NSView {
        let terminalNSView = engine.makeView()

        // Ensure the terminal view fills its container
        terminalNSView.autoresizingMask = [.width, .height]

        return terminalNSView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // The engine owns all view configuration (font, colors, etc.).
        // No updates are driven from the SwiftUI side.
    }
}
