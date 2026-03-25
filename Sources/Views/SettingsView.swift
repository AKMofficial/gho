import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            GeneralSettingsTab(settings: appState.settings)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            AppearanceSettingsTab(settings: appState.settings)
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            GitSettingsTab(settings: appState.settings)
                .tabItem {
                    Label("Git", systemImage: "arrow.triangle.branch")
                }

            KeyboardSettingsTab()
                .tabItem {
                    Label("Keyboard", systemImage: "keyboard")
                }
        }
        .frame(width: 500, height: 350)
    }
}

// MARK: - General Tab

struct GeneralSettingsTab: View {
    let settings: AppSettings

    var body: some View {
        @Bindable var s = settings

        Form {
            Section("Shell") {
                TextField("Default Shell", text: $s.defaultShell)
                    .textFieldStyle(.roundedBorder)
                Text("Path to shell executable (e.g., /bin/zsh, /bin/bash)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Session") {
                Toggle("Restore sessions on launch", isOn: $s.restoreSessionsOnLaunch)
            }

            Section("Interface") {
                Toggle("Show status bar", isOn: $s.showStatusBar)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Appearance Tab

struct AppearanceSettingsTab: View {
    let settings: AppSettings

    var body: some View {
        @Bindable var s = settings

        Form {
            Section("Terminal Font") {
                HStack {
                    TextField("Font Family", text: $s.terminalFontFamily)
                        .textFieldStyle(.roundedBorder)
                    Button("Select...") {
                        showFontPicker()
                    }
                }

                HStack {
                    Text("Size:")
                    Slider(value: $s.terminalFontSize, in: 10...24, step: 1)
                    Text("\(Int(s.terminalFontSize))px")
                        .monospacedDigit()
                        .frame(width: 40)
                }
            }

            Section("Theme") {
                Picker("Appearance", selection: $s.appearanceMode) {
                    ForEach(AppSettings.AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Color Scheme", selection: $s.terminalColorScheme) {
                    Text("Default Dark").tag("default-dark")
                    Text("Default Light").tag("default-light")
                    Text("Solarized Dark").tag("solarized-dark")
                    Text("Solarized Light").tag("solarized-light")
                    Text("Monokai").tag("monokai")
                    Text("Nord").tag("nord")
                    Text("Dracula").tag("dracula")
                }
            }

            Section("Window") {
                HStack {
                    Text("Opacity:")
                    Slider(value: $s.windowOpacity, in: 0.5...1.0, step: 0.05)
                    Text("\(Int(s.windowOpacity * 100))%")
                        .monospacedDigit()
                        .frame(width: 40)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func showFontPicker() {
        NSFontManager.shared.orderFrontFontPanel(nil)
    }
}

// MARK: - Git Tab

struct GitSettingsTab: View {
    let settings: AppSettings

    var body: some View {
        @Bindable var s = settings

        Form {
            Section("Status") {
                Toggle("Show git status in sidebar", isOn: $s.showGitInSidebar)

                Picker("Auto-refresh interval", selection: $s.gitRefreshInterval) {
                    Text("2 seconds").tag(2.0 as TimeInterval)
                    Text("5 seconds").tag(5.0 as TimeInterval)
                    Text("10 seconds").tag(10.0 as TimeInterval)
                    Text("Manual only").tag(0.0 as TimeInterval)
                }
            }

            Section("Pull Requests") {
                TextField("Default base branch", text: $s.defaultBaseBranch)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    TextField("GitHub CLI path", text: $s.ghCLIPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Detect") {
                        detectGHCLI()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func detectGHCLI() {
        let settings = settings
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            process.arguments = ["gh"]
            let pipe = Pipe()
            process.standardOutput = pipe
            try? process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !path.isEmpty {
                DispatchQueue.main.async {
                    settings.ghCLIPath = path
                }
            }
        }
    }
}

// MARK: - Keyboard Tab

struct KeyboardSettingsTab: View {
    var body: some View {
        Form {
            Section("Shortcuts") {
                shortcutRow("Add Path", shortcut: "\u{2318}\u{21e7}O")
                shortcutRow("New Terminal", shortcut: "\u{2318}T")
                shortcutRow("Close Pane", shortcut: "\u{2318}W")
                shortcutRow("Split Right", shortcut: "\u{2318}D")
                shortcutRow("Split Down", shortcut: "\u{2318}\u{21e7}D")
                shortcutRow("Command Palette", shortcut: "\u{2318}K")
                shortcutRow("Navigate Panes", shortcut: "\u{2318}\u{2325}Arrow")
                shortcutRow("Maximize Pane", shortcut: "\u{2318}\u{21e7}Enter")
                shortcutRow("Find in Terminal", shortcut: "\u{2318}F")
                shortcutRow("Settings", shortcut: "\u{2318},")
            }

            Section {
                Button("Reset to Defaults") {
                    // Reset shortcuts to defaults
                }
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func shortcutRow(_ action: String, shortcut: String) -> some View {
        HStack {
            Text(action)
            Spacer()
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}
