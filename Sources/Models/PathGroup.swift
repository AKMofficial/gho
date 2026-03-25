import Foundation

@Observable
final class PathGroup: Identifiable {
    let id: UUID
    let path: URL
    var displayName: String? = nil
    var isCollapsed: Bool = false
    var terminals: [TerminalSession] = []
    var gitState: GitState? = nil

    var effectiveName: String {
        displayName ?? path.abbreviatedPath
    }

    init(id: UUID = UUID(), path: URL, displayName: String? = nil) {
        self.id = id
        self.path = path
        self.displayName = displayName
    }
}
