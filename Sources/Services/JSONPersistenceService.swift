import Foundation

final class JSONPersistenceService: PersistenceServiceProtocol {

    private let stateURL: URL
    private let settingsKey = "com.gho.settings"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let ghoDir = appSupport.appendingPathComponent("Gho")

        try? FileManager.default.createDirectory(
            at: ghoDir,
            withIntermediateDirectories: true
        )

        self.stateURL = ghoDir.appendingPathComponent("state.json")

        self.encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        self.decoder = JSONDecoder()
    }

    // MARK: - State Persistence

    func save(state: PersistedState) throws {
        let data = try encoder.encode(state)
        try data.write(to: stateURL, options: .atomic)
    }

    func load() throws -> PersistedState? {
        let data: Data
        do {
            data = try Data(contentsOf: stateURL)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain
            && error.code == NSFileReadNoSuchFileError {
            return nil
        }
        return try decoder.decode(PersistedState.self, from: data)
    }

    // MARK: - Settings Persistence

    func saveSettings(_ settings: AppSettings) throws {
        let data = try encoder.encode(SettingsCodable(from: settings))
        UserDefaults.standard.set(data, forKey: settingsKey)
    }

    func loadSettings() throws -> AppSettings? {
        guard let data = UserDefaults.standard.data(forKey: settingsKey) else {
            return nil
        }
        let codable = try decoder.decode(SettingsCodable.self, from: data)
        return codable.toAppSettings()
    }

    // MARK: - Conversion Helpers

    /// Convert AppState to PersistedState for saving.
    static func persistedState(from appState: AppState) -> PersistedState {
        let groups = appState.pathGroups.map { group in
            PersistedState.PersistedPathGroup(
                id: group.id,
                path: group.path.path,
                displayName: group.displayName,
                isCollapsed: group.isCollapsed,
                terminals: group.terminals.map { terminal in
                    PersistedState.PersistedTerminal(
                        id: terminal.id,
                        label: terminal.label
                    )
                }
            )
        }

        let splitRoot = appState.splitRoot.map { persistedSplitNode(from: $0) }

        return PersistedState(
            windowFrame: nil,
            sidebarWidth: appState.sidebarWidth,
            pathGroups: groups,
            activeTerminalID: appState.activeTerminalID,
            splitRoot: splitRoot
        )
    }

    private static func persistedSplitNode(
        from node: SplitNode
    ) -> PersistedState.PersistedSplitNode {
        switch node {
        case .leaf(let id, let terminalID):
            return PersistedState.PersistedSplitNode(
                kind: .leaf,
                id: id,
                terminalID: terminalID,
                direction: nil,
                ratio: nil,
                first: nil,
                second: nil
            )
        case .split(let id, let direction, let ratio, let first, let second):
            return PersistedState.PersistedSplitNode(
                kind: .split,
                id: id,
                terminalID: nil,
                direction: direction.rawValue,
                ratio: ratio,
                first: persistedSplitNode(from: first),
                second: persistedSplitNode(from: second)
            )
        }
    }

    /// Convert PersistedState back to populate AppState.
    static func restoreAppState(
        from persisted: PersistedState,
        into appState: AppState,
        sessionManager: TerminalSessionManager
    ) {
        appState.sidebarWidth = persisted.sidebarWidth
        appState.activeTerminalID = persisted.activeTerminalID

        for pGroup in persisted.pathGroups {
            let url = URL(fileURLWithPath: pGroup.path)
            let group = PathGroup(id: pGroup.id, path: url)
            group.displayName = pGroup.displayName
            group.isCollapsed = pGroup.isCollapsed

            for pTerminal in pGroup.terminals {
                let session = sessionManager.createSession(
                    in: group,
                    label: pTerminal.label
                )
                group.terminals.append(session)
            }

            appState.pathGroups.append(group)
        }

        if let pSplit = persisted.splitRoot {
            appState.splitRoot = restoreSplitNode(from: pSplit)
        }
    }

    private static func restoreSplitNode(
        from persisted: PersistedState.PersistedSplitNode
    ) -> SplitNode? {
        switch persisted.kind {
        case .leaf:
            guard let terminalID = persisted.terminalID else { return nil }
            return .leaf(id: persisted.id, terminalID: terminalID)
        case .split:
            guard let dirStr = persisted.direction,
                  let direction = SplitDirection(rawValue: dirStr),
                  let ratio = persisted.ratio,
                  let first = persisted.first.flatMap({ restoreSplitNode(from: $0) }),
                  let second = persisted.second.flatMap({ restoreSplitNode(from: $0) })
            else { return nil }
            return .split(
                id: persisted.id,
                direction: direction,
                ratio: ratio,
                first: first,
                second: second
            )
        }
    }
}

// MARK: - Settings Codable Wrapper

/// Codable wrapper for AppSettings (since @Observable classes are not directly Codable).
private struct SettingsCodable: Codable {
    let defaultShell: String
    let restoreSessionsOnLaunch: Bool
    let showStatusBar: Bool
    let terminalFontFamily: String
    let terminalFontSize: CGFloat
    let terminalColorScheme: String
    let windowOpacity: CGFloat
    let appearanceMode: String
    let gitRefreshInterval: TimeInterval
    let defaultBaseBranch: String
    let showGitInSidebar: Bool
    let ghCLIPath: String

    init(from settings: AppSettings) {
        self.defaultShell = settings.defaultShell
        self.restoreSessionsOnLaunch = settings.restoreSessionsOnLaunch
        self.showStatusBar = settings.showStatusBar
        self.terminalFontFamily = settings.terminalFontFamily
        self.terminalFontSize = settings.terminalFontSize
        self.terminalColorScheme = settings.terminalColorScheme
        self.windowOpacity = settings.windowOpacity
        self.appearanceMode = settings.appearanceMode.rawValue
        self.gitRefreshInterval = settings.gitRefreshInterval
        self.defaultBaseBranch = settings.defaultBaseBranch
        self.showGitInSidebar = settings.showGitInSidebar
        self.ghCLIPath = settings.ghCLIPath
    }

    func toAppSettings() -> AppSettings {
        let s = AppSettings()
        s.defaultShell = defaultShell
        s.restoreSessionsOnLaunch = restoreSessionsOnLaunch
        s.showStatusBar = showStatusBar
        s.terminalFontFamily = terminalFontFamily
        s.terminalFontSize = terminalFontSize
        s.terminalColorScheme = terminalColorScheme
        s.windowOpacity = windowOpacity
        s.appearanceMode = AppSettings.AppearanceMode(rawValue: appearanceMode) ?? .system
        s.gitRefreshInterval = gitRefreshInterval
        s.defaultBaseBranch = defaultBaseBranch
        s.showGitInSidebar = showGitInSidebar
        s.ghCLIPath = ghCLIPath
        return s
    }
}
