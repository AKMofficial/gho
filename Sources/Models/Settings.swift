import Foundation

@Observable
final class AppSettings {
    var defaultShell: String = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    var restoreSessionsOnLaunch: Bool = true
    var showStatusBar: Bool = true
    var terminalFontFamily: String = "SF Mono"
    var terminalFontSize: CGFloat = 13
    var terminalColorScheme: String = "default-dark"
    var windowOpacity: CGFloat = 1.0
    var appearanceMode: AppearanceMode = .system
    var gitRefreshInterval: TimeInterval = 2.0
    var defaultBaseBranch: String = "main"
    var showGitInSidebar: Bool = true
    var ghCLIPath: String = "/usr/local/bin/gh"

    enum AppearanceMode: String, Codable, CaseIterable {
        case system
        case light
        case dark
    }
}
