import Foundation

enum SplitDirection: String, Codable {
    case horizontal
    case vertical
}

indirect enum SplitNode: Identifiable, Equatable {
    case leaf(id: UUID, terminalID: UUID)
    case split(id: UUID, direction: SplitDirection, ratio: CGFloat, first: SplitNode, second: SplitNode)

    var id: UUID {
        switch self {
        case .leaf(let id, _):
            return id
        case .split(let id, _, _, _, _):
            return id
        }
    }

    var allTerminalIDs: [UUID] {
        switch self {
        case .leaf(_, let terminalID):
            return [terminalID]
        case .split(_, _, _, let first, let second):
            return first.allTerminalIDs + second.allTerminalIDs
        }
    }

    func find(terminalID: UUID) -> SplitNode? {
        switch self {
        case .leaf(_, let tid):
            return tid == terminalID ? self : nil
        case .split(_, _, _, let first, let second):
            return first.find(terminalID: terminalID) ?? second.find(terminalID: terminalID)
        }
    }

    func splitting(leafID: UUID, direction: SplitDirection, newTerminalID: UUID) -> SplitNode {
        switch self {
        case .leaf(let id, let terminalID):
            if id == leafID {
                let newLeaf = SplitNode.leaf(id: UUID(), terminalID: newTerminalID)
                return .split(
                    id: UUID(),
                    direction: direction,
                    ratio: 0.5,
                    first: self,
                    second: newLeaf
                )
            }
            return .leaf(id: id, terminalID: terminalID)

        case .split(let id, let dir, let ratio, let first, let second):
            return .split(
                id: id,
                direction: dir,
                ratio: ratio,
                first: first.splitting(leafID: leafID, direction: direction, newTerminalID: newTerminalID),
                second: second.splitting(leafID: leafID, direction: direction, newTerminalID: newTerminalID)
            )
        }
    }

    func removing(leafID: UUID) -> SplitNode? {
        switch self {
        case .leaf(let id, _):
            return id == leafID ? nil : self

        case .split(let id, let direction, let ratio, let first, let second):
            let newFirst = first.removing(leafID: leafID)
            let newSecond = second.removing(leafID: leafID)

            switch (newFirst, newSecond) {
            case (nil, nil):
                return nil
            case (nil, let remaining):
                return remaining
            case (let remaining, nil):
                return remaining
            case (let first?, let second?):
                return .split(id: id, direction: direction, ratio: ratio, first: first, second: second)
            }
        }
    }

    func withUpdatedRatio(splitID: UUID, newRatio: CGFloat) -> SplitNode {
        switch self {
        case .leaf:
            return self

        case .split(let id, let direction, let ratio, let first, let second):
            if id == splitID {
                return .split(id: id, direction: direction, ratio: newRatio, first: first, second: second)
            }
            return .split(
                id: id,
                direction: direction,
                ratio: ratio,
                first: first.withUpdatedRatio(splitID: splitID, newRatio: newRatio),
                second: second.withUpdatedRatio(splitID: splitID, newRatio: newRatio)
            )
        }
    }

    static func == (lhs: SplitNode, rhs: SplitNode) -> Bool {
        switch (lhs, rhs) {
        case let (.leaf(lhsID, lhsTerminalID), .leaf(rhsID, rhsTerminalID)):
            return lhsID == rhsID && lhsTerminalID == rhsTerminalID

        case let (.split(lhsID, lhsDir, lhsRatio, lhsFirst, lhsSecond),
                   .split(rhsID, rhsDir, rhsRatio, rhsFirst, rhsSecond)):
            return lhsID == rhsID
                && lhsDir == rhsDir
                && lhsRatio == rhsRatio
                && lhsFirst == rhsFirst
                && lhsSecond == rhsSecond

        default:
            return false
        }
    }
}
