import SwiftUI

enum TerminalStatus: String, Codable, CaseIterable {
    case idle
    case running
    case error
    case aiAgent

    var color: Color {
        switch self {
        case .idle: return .gray
        case .running: return .green
        case .error: return .red
        case .aiAgent: return .orange
        }
    }

    var label: String {
        switch self {
        case .idle: return "Idle"
        case .running: return "Running"
        case .error: return "Error"
        case .aiAgent: return "AI Agent"
        }
    }
}

@Observable
final class TerminalSession: Identifiable {
    let id: UUID
    var label: String
    var status: TerminalStatus = .idle
    var workingDirectory: URL
    let pathGroupID: UUID
    var exitCode: Int32? = nil

    init(id: UUID = UUID(), label: String, workingDirectory: URL, pathGroupID: UUID) {
        self.id = id
        self.label = label
        self.workingDirectory = workingDirectory
        self.pathGroupID = pathGroupID
    }
}
