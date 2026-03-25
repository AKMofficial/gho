import SwiftUI

@Observable
final class AppState {
    var pathGroups: [PathGroup] = []
    var activeTerminalID: UUID? = nil
    var splitRoot: SplitNode? = nil
    var sidebarWidth: CGFloat = 240
    var isCommandPaletteVisible: Bool = false
    var isSidebarVisible: Bool = true
    var maximizedPaneID: UUID? = nil
    var settings: AppSettings = AppSettings()

    // MARK: - Computed Properties

    var activePathGroup: PathGroup? {
        guard let activeID = activeTerminalID else { return nil }
        return pathGroups.first { group in
            group.terminals.contains { $0.id == activeID }
        }
    }

    var activeTerminal: TerminalSession? {
        guard let activeID = activeTerminalID else { return nil }
        for group in pathGroups {
            if let terminal = group.terminals.first(where: { $0.id == activeID }) {
                return terminal
            }
        }
        return nil
    }

    // MARK: - Path Group Management

    @discardableResult
    func addPathGroup(path: URL) -> PathGroup {
        let group = PathGroup(path: path)
        pathGroups.append(group)
        return group
    }

    func removePathGroup(id: UUID) {
        guard let group = pathGroups.first(where: { $0.id == id }) else { return }
        for terminal in group.terminals {
            removeLeafFromSplitRoot(terminalID: terminal.id)
        }
        pathGroups.removeAll { $0.id == id }
    }

    // NOTE: sessionManager (TerminalSessionManager) is defined in Unit 3.
    // These methods reference it by type name. The app won't compile until all units merge.

    // func addTerminal(to groupID: UUID, sessionManager: TerminalSessionManager) -> TerminalSession {
    //     Creates session via sessionManager, adds to group, adds leaf to splitRoot
    // }

    // func removeTerminal(id: UUID, sessionManager: TerminalSessionManager) {
    //     Destroys session, removes from splitRoot
    // }

    func focusTerminal(id: UUID) {
        activeTerminalID = id
    }

    // func splitActive(direction: SplitDirection, sessionManager: TerminalSessionManager) {
    //     Finds active leaf in splitRoot, replaces with split containing old + new terminal
    // }

    // func closePane(id: UUID, sessionManager: TerminalSessionManager) {
    //     Removes leaf from splitRoot (collapsing parent split), destroys session
    // }

    func movePathGroup(from: IndexSet, to: Int) {
        pathGroups.move(fromOffsets: from, toOffset: to)
    }

    // MARK: - Split Tree Helpers (no sessionManager dependency)

    func addLeafToSplitRoot(terminalID: UUID) {
        let newLeaf = SplitNode.leaf(id: UUID(), terminalID: terminalID)
        if let existing = splitRoot {
            splitRoot = .split(
                id: UUID(),
                direction: .horizontal,
                ratio: 0.5,
                first: existing,
                second: newLeaf
            )
        } else {
            splitRoot = newLeaf
        }
    }

    func removeLeafFromSplitRoot(terminalID: UUID) {
        guard let root = splitRoot else { return }
        if let leaf = root.find(terminalID: terminalID) {
            splitRoot = root.removing(leafID: leaf.id)
        }
    }
}
