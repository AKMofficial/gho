import SwiftUI

/// Recursively renders a ``SplitNode`` tree as nested split panes
/// with draggable dividers.
///
/// - `.leaf` nodes render a ``TerminalPaneView``.
/// - `.split` nodes render two children separated by a ``SplitDivider``.
struct SplitContainerView: View {

    let node: SplitNode

    var body: some View {
        switch node {
        case .leaf(_, let terminalID):
            TerminalPaneView(terminalID: terminalID)

        case .split(let id, let direction, let ratio, let first, let second):
            GeometryReader { geometry in
                if direction == .horizontal {
                    HStack(spacing: 0) {
                        SplitContainerView(node: first)
                            .frame(
                                width: max(
                                    200,
                                    geometry.size.width * ratio - 2
                                )
                            )

                        SplitDivider(
                            direction: .horizontal,
                            splitID: id,
                            geometry: geometry
                        )

                        SplitContainerView(node: second)
                    }
                } else {
                    VStack(spacing: 0) {
                        SplitContainerView(node: first)
                            .frame(
                                height: max(
                                    100,
                                    geometry.size.height * ratio - 2
                                )
                            )

                        SplitDivider(
                            direction: .vertical,
                            splitID: id,
                            geometry: geometry
                        )

                        SplitContainerView(node: second)
                    }
                }
            }
        }
    }
}

// MARK: - SplitDivider

/// A draggable divider between two split panes.
///
/// When `direction` is `.horizontal`, the divider is a thin vertical bar
/// between left and right children. When `.vertical`, it is a thin
/// horizontal bar between top and bottom children.
///
/// Double-clicking the divider resets the split ratio to 0.5 (equal sizes).
struct SplitDivider: View {

    let direction: SplitDirection
    let splitID: UUID
    let geometry: GeometryProxy

    @Environment(AppState.self) private var appState
    @State private var isDragging = false

    var body: some View {
        Rectangle()
            .fill(
                isDragging
                    ? Color.accentColor.opacity(0.5)
                    : Color.gray.opacity(0.1)
            )
            .frame(
                width: direction == .horizontal ? 4 : nil,
                height: direction == .vertical ? 4 : nil
            )
            .contentShape(Rectangle())
            .onHover { isHovered in
                if isHovered {
                    if direction == .horizontal {
                        NSCursor.resizeLeftRight.push()
                    } else {
                        NSCursor.resizeUpDown.push()
                    }
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let totalSize: CGFloat
                        let position: CGFloat

                        if direction == .horizontal {
                            totalSize = geometry.size.width
                            position = value.location.x
                        } else {
                            totalSize = geometry.size.height
                            position = value.location.y
                        }

                        guard totalSize > 0 else { return }

                        let newRatio = min(0.9, max(0.1, position / totalSize))

                        if let root = appState.splitRoot {
                            appState.splitRoot = root.withUpdatedRatio(
                                splitID: splitID,
                                newRatio: newRatio
                            )
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onTapGesture(count: 2) {
                // Double-click resets to equal sizes
                if let root = appState.splitRoot {
                    appState.splitRoot = root.withUpdatedRatio(
                        splitID: splitID,
                        newRatio: 0.5
                    )
                }
            }
    }
}
