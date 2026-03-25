import Foundation

// MARK: - Persisted State Snapshot

struct PersistedState: Codable {
    struct PersistedPathGroup: Codable {
        let id: UUID
        let path: String
        let displayName: String?
        let isCollapsed: Bool
        let terminals: [PersistedTerminal]
    }

    struct PersistedTerminal: Codable {
        let id: UUID
        let label: String
    }

    final class PersistedSplitNode: Codable {
        enum NodeKind: String, Codable {
            case leaf
            case split
        }

        let kind: NodeKind
        let id: UUID
        let terminalID: UUID?
        let direction: String?
        let ratio: CGFloat?
        let first: PersistedSplitNode?
        let second: PersistedSplitNode?

        init(kind: NodeKind, id: UUID, terminalID: UUID?, direction: String?, ratio: CGFloat?, first: PersistedSplitNode?, second: PersistedSplitNode?) {
            self.kind = kind
            self.id = id
            self.terminalID = terminalID
            self.direction = direction
            self.ratio = ratio
            self.first = first
            self.second = second
        }
    }

    let windowFrame: CGRect?
    let sidebarWidth: CGFloat
    let pathGroups: [PersistedPathGroup]
    let activeTerminalID: UUID?
    let splitRoot: PersistedSplitNode?
}

// MARK: - Protocol

protocol PersistenceServiceProtocol {
    func save(state: PersistedState) throws
    func load() throws -> PersistedState?
    func saveSettings(_ settings: AppSettings) throws
    func loadSettings() throws -> AppSettings?
}
