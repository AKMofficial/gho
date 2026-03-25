import SwiftUI

enum NavigationDirection {
    case left, right, up, down
}

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

    @discardableResult
    func addTerminal(to groupID: UUID, sessionManager: TerminalSessionManager) -> TerminalSession {
        guard let group = pathGroups.first(where: { $0.id == groupID }) else {
            fatalError("PathGroup \(groupID) not found")
        }
        let session = sessionManager.createSession(in: group)
        group.terminals.append(session)
        addLeafToSplitRoot(terminalID: session.id)
        activeTerminalID = session.id
        return session
    }

    func removeTerminal(id: UUID, sessionManager: TerminalSessionManager) {
        sessionManager.destroySession(id: id)
        removeLeafFromSplitRoot(terminalID: id)
        for group in pathGroups {
            group.terminals.removeAll { $0.id == id }
        }
        if activeTerminalID == id {
            activeTerminalID = splitRoot?.allTerminalIDs.first
        }
    }

    func focusTerminal(id: UUID) {
        activeTerminalID = id
    }

    func splitActive(direction: SplitDirection, sessionManager: TerminalSessionManager) {
        guard let activeID = activeTerminalID,
              let group = activePathGroup else { return }
        let newSession = sessionManager.createSession(in: group)
        group.terminals.append(newSession)
        if let root = splitRoot,
           let leaf = root.find(terminalID: activeID) {
            splitRoot = root.splitting(
                leafID: leaf.id,
                direction: direction,
                newTerminalID: newSession.id
            )
        } else {
            addLeafToSplitRoot(terminalID: newSession.id)
        }
        activeTerminalID = newSession.id
    }

    func closePane(id: UUID, sessionManager: TerminalSessionManager) {
        removeTerminal(id: id, sessionManager: sessionManager)
    }

    func movePathGroup(from: IndexSet, to: Int) {
        pathGroups.move(fromOffsets: from, toOffset: to)
    }

    func navigatePane(direction: NavigationDirection) {
        guard let root = splitRoot,
              let activeID = activeTerminalID else { return }

        let allIDs = root.allTerminalIDs
        guard allIDs.count > 1,
              let currentIndex = allIDs.firstIndex(of: activeID) else { return }

        // Simple linear navigation: left/up goes to previous, right/down goes to next
        // allTerminalIDs returns them in tree order (left-to-right, top-to-bottom)
        let newIndex: Int
        switch direction {
        case .left, .up:
            newIndex = currentIndex > 0 ? currentIndex - 1 : allIDs.count - 1
        case .right, .down:
            newIndex = currentIndex < allIDs.count - 1 ? currentIndex + 1 : 0
        }

        focusTerminal(id: allIDs[newIndex])
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
