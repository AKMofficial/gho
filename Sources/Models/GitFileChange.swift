import Foundation

enum GitChangeKind: String, Codable {
    case modified
    case added
    case deleted
    case renamed
    case copied
    case typeChanged
    case untracked

    var symbol: String {
        switch self {
        case .modified: return "pencil.circle"
        case .added: return "plus.circle"
        case .deleted: return "minus.circle"
        case .renamed: return "arrow.right.circle"
        case .copied: return "doc.on.doc"
        case .typeChanged: return "arrow.triangle.2.circlepath"
        case .untracked: return "questionmark.circle"
        }
    }
}

struct GitFileChange: Identifiable, Hashable {
    let id: String
    let path: String
    let oldPath: String?
    let kind: GitChangeKind

    init(path: String, kind: GitChangeKind, oldPath: String? = nil) {
        self.id = path
        self.path = path
        self.oldPath = oldPath
        self.kind = kind
    }
}
