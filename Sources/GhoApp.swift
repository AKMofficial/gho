import SwiftUI

@main
struct GhoApp: App {
    @State private var appState = AppState()
    @State private var sessionManager: TerminalSessionManager?

    private let gitService = GitCLIService()
    private let fileWatcher = FSEventsWatcher()
    private let persistenceService = JSONPersistenceService()

    var body: some Scene {
        WindowGroup {
            Group {
                if let sessionManager {
                    ContentView()
                        .environment(appState)
                        .environment(sessionManager)
                } else {
                    Color.clear
                }
            }
            .onAppear {
                bootstrapApp()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: NSApplication.willTerminateNotification
                )
            ) { _ in
                saveState()
            }
        }
        .commands {
            if let sessionManager {
                GhoCommands(appState: appState, sessionManager: sessionManager)
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
    }

    // MARK: - Bootstrap

    private func bootstrapApp() {
        let sm = TerminalSessionManager(appState: appState)
        sessionManager = sm

        if let settings = try? persistenceService.loadSettings() {
            appState.settings = settings
        }

        if appState.settings.restoreSessionsOnLaunch,
           let persisted = try? persistenceService.load() {
            JSONPersistenceService.restoreAppState(
                from: persisted,
                into: appState,
                sessionManager: sm
            )
        }

        for group in appState.pathGroups {
            detectGitAndWatch(group: group)
        }
    }

    // MARK: - Persistence

    private func saveState() {
        let state = JSONPersistenceService.persistedState(from: appState)
        try? persistenceService.save(state: state)
        try? persistenceService.saveSettings(appState.settings)
        fileWatcher.stopAll()
    }

    // MARK: - Git Integration

    private func detectGitAndWatch(group: PathGroup) {
        let gitService = self.gitService
        let fileWatcher = self.fileWatcher
        let refreshInterval = appState.settings.gitRefreshInterval

        Task {
            guard await gitService.isGitRepository(at: group.path) else { return }

            if let status = try? await gitService.getStatus(at: group.path) {
                await MainActor.run {
                    group.gitState = status
                }
            }

            guard refreshInterval > 0 else { return }

            await MainActor.run {
                fileWatcher.watch(directory: group.path) {
                    Task {
                        if let newStatus = try? await gitService.getStatus(
                            at: group.path
                        ) {
                            group.gitState = newStatus
                        }
                    }
                }
            }
        }
    }
}
