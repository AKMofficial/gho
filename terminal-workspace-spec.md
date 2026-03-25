# Terminal Workspace — Product Specification

> A macOS-native terminal workspace built for AI-powered development.
> No code editor. The terminal IS the editor. AI tools (Claude Code, Opencode, etc.) handle all code changes from within terminal sessions.

---

## Tech Stack

| Layer           | Technology                                        |
| --------------- | ------------------------------------------------- |
| Language        | Swift 6                                           |
| UI Framework    | SwiftUI + AppKit (hybrid where needed)            |
| Terminal Engine | libghostty (C-ABI, Metal GPU rendering)           |
| Git Operations  | libgit2 via SwiftGit2 (or shell out to `git` CLI) |
| Platform        | macOS only (14.0+ Sonoma minimum)                 |
| Build System    | Xcode + Swift Package Manager                     |
| Architecture    | MVVM with observable state                        |

### Why These Choices

- **libghostty**: SIMD-optimized VTE parsing, Metal GPU rendering, native macOS performance. Used by Calyx, cmux, OrbStack.
- **SwiftUI**: Native macOS look and feel out of the box — sidebar, split views, popovers all match system style automatically.
- **libgit2**: No dependency on git CLI installation. Direct C library for all git operations (status, diff, stage, commit, push, branch).

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│  App (SwiftUI)                                          │
│                                                         │
│  ┌────────────┐  ┌──────────────────────────────────┐   │
│  │  Sidebar   │  │  Terminal Area                    │   │
│  │            │  │                                    │   │
│  │ Path Groups│  │  ┌────────────┬────────────────┐  │   │
│  │ + Terminals│  │  │ Terminal A │ Terminal B      │  │   │
│  │ + Git State│  │  │ (active)   │ (split right)   │  │   │
│  │            │  │  │            │                  │  │   │
│  └────────────┘  │  └────────────┴────────────────┘  │   │
│                  └──────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────────┐│
│  │  Core Services (Swift)                              ││
│  │  ├ TerminalSessionManager (libghostty + PTY)        ││
│  │  ├ GitService (libgit2 — status, diff, stage, etc.) ││
│  │  ├ PathGroupManager (workspace state)               ││
│  │  └ FileWatcher (DispatchSource / FSEvents)          ││
│  └─────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
```

---

## UI Design — Mac-Native Look

The app should look and feel like a first-party Apple app. Think: Xcode's navigator + Terminal.app merged.

### Window Layout

```
┌──────────────────────────────────────────────────────────────┐
│ ● ● ●              Terminal Workspace              ─ □ ✕    │
├──────────────┬───────────────────────────────────────────────┤
│              │                                               │
│   SIDEBAR    │              TERMINAL AREA                    │
│   (240px)    │                                               │
│              │   Terminals render here.                      │
│   Resizable  │   Supports single, split horizontal,          │
│   drag edge  │   split vertical, and grid layouts.           │
│              │                                               │
├──────────────┴───────────────────────────────────────────────┤
│  Status Bar: current path · git branch · staged count        │
└──────────────────────────────────────────────────────────────┘
```

### Color & Style

- Follow macOS system appearance (auto light/dark mode)
- Sidebar: `.sidebar` style with translucent material background (NSVisualEffectView / `.ultraThinMaterial`)
- Terminal area: solid dark background (user-configurable, default: #1a1a1a)
- Accent color: system blue (follows macOS accent color setting)
- Typography: SF Pro for UI, SF Mono / user-configured monospace for terminal
- Icons: SF Symbols throughout (native, resolution-independent)
- Spacing: 8px base unit, consistent with Apple HIG
- Dividers: thin hairline separators at 10% opacity
- No custom chrome — use native title bar with toolbar style

---

## Sidebar — Detailed Specification

The sidebar is the core navigation element. It shows all workspace paths, their terminal sessions, and git state.

### Structure

```
SIDEBAR
├─ [+ Add Path]  (button at top)
│
├─ 📁 ~/projects/my-app            ← Path Group (collapsible)
│  ├─ ● Terminal 1                  ← Terminal session (click to focus)
│  ├─ ● Terminal 2                  ← Active terminal has highlight
│  ├─ [+]                           ← Add new terminal in this path
│  └─ ┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈         ← Separator
│     Git: main                     ← Current branch
│     ● 3 staged                    ← Staged changes count
│     ○ 5 unstaged                  ← Unstaged changes count
│     ▸ View Changes                ← Expand to see file list + diff
│     ▸ Push · PR · Branch          ← Quick actions
│
├─ 📁 ~/projects/api-server         ← Another path group
│  ├─ ● Terminal 3
│  ├─ [+]
│  └─ ┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈
│     Git: feature/auth
│     ● 0 staged
│     ○ 2 unstaged
│     ▸ View Changes
│     ▸ Push · PR · Branch
│
└─ 📁 ~/dotfiles
   ├─ ● Terminal 4
   ├─ [+]
   └─ (no git repo detected)
```

### Add Path (Top Button)

- Location: top of sidebar, always visible
- Icon: SF Symbol `plus.circle` or `folder.badge.plus`
- Click behavior: opens native macOS folder picker (`NSOpenPanel`)
- After selection: new path group appears in sidebar with one terminal auto-created in that directory
- Keyboard shortcut: `Cmd+Shift+O`
- The path is persisted across app launches (saved to UserDefaults or a JSON config file)

### Path Group

- Shows the directory path (abbreviated: `~/projects/my-app` not full `/Users/akm/...`)
- Collapsible with disclosure triangle (click to collapse/expand)
- Right-click context menu:
  - "Open in Finder"
  - "Copy Path"
  - "Remove Path" (closes all terminals in this group, removes from sidebar)
  - "Rename" (custom display name, optional)
- Drag to reorder path groups

### Terminal Sessions Within a Path Group

- Each terminal is a row: colored dot (status indicator) + label
- Label: auto-generated ("Terminal 1", "Terminal 2") or user-renamable (double-click to edit)
- Status dot colors:
  - Green: active/running process
  - Gray: idle (shell prompt waiting)
  - Red: process exited with error
  - Orange: AI agent running (detect by process name: `claude`, `opencode`, etc.)
- Click: focuses that terminal in the main area
- Right-click context menu:
  - "Rename"
  - "Split Right" (creates side-by-side split with new terminal)
  - "Split Down" (creates vertical split with new terminal)
  - "Close Terminal" (with confirmation if process is running)
- Active terminal row has a subtle highlight background
- Drag terminal between path groups to move it

### [+] Add Terminal Button

- Appears as last item in each path group's terminal list
- Icon: SF Symbol `plus` (small, subtle)
- Click: creates a new terminal session in that path group's directory
- The new terminal opens in the main area and the shell starts in the correct working directory
- Keyboard shortcut (when group is focused): `Cmd+T`

### Git Section Within a Path Group

Only shown if the path is inside a git repository. Auto-detected on path addition and re-checked via filesystem watcher.

#### Branch Display

- Shows current branch name with SF Symbol `arrow.triangle.branch`
- Click: opens branch picker popover
  - Lists all local branches
  - Search/filter field at top
  - Click a branch to switch (with confirmation if there are uncommitted changes)
  - "New Branch..." option at bottom

#### Staged / Unstaged Counts

- Compact display: "● 3 staged · ○ 5 unstaged"
- Green dot for staged, gray dot for unstaged
- Numbers update in real-time via filesystem watcher on `.git` directory

#### View Changes (Expandable)

When expanded, shows:

```
▾ View Changes
  Staged:
    ✓ src/auth.ts          (modified)
    ✓ src/utils/hash.ts    (new file)
    ✓ package.json         (modified)
  Unstaged:
    ○ src/routes/api.ts    (modified)
    ○ src/db/schema.ts     (modified)
    ○ README.md            (modified)
    ○ .env.example         (new file)
    ○ tests/auth.test.ts   (deleted)
```

- Click on any file: opens a diff popover/sheet showing the changes
- Diff display: side-by-side or unified (user preference), syntax highlighted
- Right-click on unstaged file: "Stage File", "Discard Changes"
- Right-click on staged file: "Unstage File"
- "Stage All" / "Unstage All" buttons at section headers
- Checkbox per file for batch staging/unstaging

#### Quick Actions Row

```
[Push ↑] [Pull ↓] [PR] [Stash]
```

- **Push**: pushes current branch to origin. Shows confirmation with commit count. Disabled if nothing to push.
- **Pull**: pulls from origin. Shows incoming commit count if available.
- **PR**: opens a form to create a pull request
  - Title field (auto-populated from branch name)
  - Description field (markdown)
  - Base branch selector (default: main)
  - Uses `gh` CLI under the hood
  - Shows PR URL after creation
- **Stash**: quick stash/pop. Dropdown shows stash list.

---

## Terminal Area — Detailed Specification

### Single Terminal View

- Terminal fills the entire main area
- Rendered by libghostty with Metal GPU acceleration
- Standard terminal features: scrollback buffer, selection, copy/paste, clickable URLs
- Font: SF Mono (default), user-configurable
- Font size: 13px default, Cmd+Plus/Minus to adjust
- Color scheme: follows a terminal theme (default: dark, user-configurable)

### Split Panes

Users can split the terminal area to see multiple terminals side by side.

```
HORIZONTAL SPLIT:
┌──────────────────┬──────────────────┐
│                  │                  │
│   Terminal A     │   Terminal B     │
│                  │                  │
└──────────────────┴──────────────────┘

VERTICAL SPLIT:
┌─────────────────────────────────────┐
│            Terminal A               │
├─────────────────────────────────────┤
│            Terminal B               │
└─────────────────────────────────────┘

GRID (2x2):
┌──────────────────┬──────────────────┐
│   Terminal A     │   Terminal B     │
├──────────────────┼──────────────────┤
│   Terminal C     │   Terminal D     │
└──────────────────┴──────────────────┘
```

- Split dividers are draggable to resize panes
- Minimum pane size: 200px width, 100px height
- Active pane has a subtle border highlight (1px accent color)
- Keyboard shortcuts:
  - `Cmd+D`: split right
  - `Cmd+Shift+D`: split down
  - `Cmd+W`: close current pane
  - `Cmd+Option+Arrow`: navigate between panes
  - `Cmd+Shift+Enter`: maximize/restore current pane (toggle)
- Double-click divider: reset to equal sizes

### Tab Bar (Optional, Within Terminal Area)

If a path group has multiple terminals but the user is not in split view, show a minimal tab bar at the top of the terminal area:

```
┌─[ Terminal 1 ]──[ Terminal 2 ]──[ Terminal 3 ]──[+]─────────┐
│                                                              │
│  Terminal content here...                                    │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

- Tabs are draggable to reorder
- Cmd+1/2/3... to switch tabs
- Cmd+Shift+] and Cmd+Shift+[ to cycle tabs

---

## Status Bar — Bottom

A thin bar at the very bottom of the window:

```
┌──────────────────────────────────────────────────────────────┐
│ ~/projects/my-app  ·  main  ·  ● 3 staged  ○ 5 unstaged    │
└──────────────────────────────────────────────────────────────┘
```

- Shows info for the currently active terminal's path group
- Clicking the branch name → same branch picker as sidebar
- Clicking staged/unstaged counts → opens the changes view
- Minimal and unobtrusive — 24px height, small text (11-12px)

---

## Keyboard Shortcuts — Full List

### Global

| Shortcut      | Action                                             |
| ------------- | -------------------------------------------------- |
| `Cmd+Shift+O` | Add new path (folder picker)                       |
| `Cmd+T`       | New terminal in current path group                 |
| `Cmd+W`       | Close current terminal pane                        |
| `Cmd+Shift+W` | Close entire path group                            |
| `Cmd+,`       | Open settings                                      |
| `Cmd+K`       | Command palette (search actions, paths, terminals) |

### Terminal

| Shortcut           | Action                                                      |
| ------------------ | ----------------------------------------------------------- |
| `Cmd+D`            | Split right                                                 |
| `Cmd+Shift+D`      | Split down                                                  |
| `Cmd+Option+Arrow` | Navigate between split panes                                |
| `Cmd+Shift+Enter`  | Maximize/restore pane                                       |
| `Cmd+1-9`          | Switch to terminal tab N                                    |
| `Cmd+Shift+]`      | Next tab                                                    |
| `Cmd+Shift+[`      | Previous tab                                                |
| `Cmd+Plus`         | Increase font size                                          |
| `Cmd+Minus`        | Decrease font size                                          |
| `Cmd+0`            | Reset font size                                             |
| `Cmd+C`            | Copy (when text selected) / send SIGINT (when no selection) |
| `Cmd+V`            | Paste                                                       |
| `Cmd+F`            | Find in terminal scrollback                                 |
| `Cmd+Shift+C`      | Copy terminal output block                                  |

### Git (when sidebar git section focused)

| Shortcut      | Action                                    |
| ------------- | ----------------------------------------- |
| `Cmd+Shift+S` | Stage all changes                         |
| `Cmd+Shift+U` | Unstage all changes                       |
| `Cmd+Enter`   | Quick commit (opens commit message input) |
| `Cmd+Shift+P` | Push                                      |

---

## Command Palette

Triggered by `Cmd+K`. A macOS-native search bar overlay (like Spotlight):

```
┌───────────────────────────────────────┐
│ 🔍 Search commands, paths, terminals  │
├───────────────────────────────────────┤
│ > New Terminal                        │
│ > Add Path...                         │
│ > Switch Branch: my-app               │
│ > Push: my-app (3 commits ahead)      │
│ > Focus: Terminal 2 (api-server)      │
│ > Settings                            │
└───────────────────────────────────────┘
```

- Fuzzy search across commands, path names, terminal names
- Most recent / most used actions ranked first
- Enter to execute, Escape to dismiss

---

## Settings

Accessible via `Cmd+,`. Native macOS settings window with tabs:

### General

- Default shell: auto-detect or manual path (`/bin/zsh`, `/bin/bash`, etc.)
- Default working directory for new paths
- Restore sessions on launch: on/off
- Show status bar: on/off

### Appearance

- Terminal color scheme: preset themes + custom
- Terminal font: font picker (default SF Mono)
- Terminal font size: slider (10-24px)
- Sidebar position: left / right
- Window opacity: slider (for terminal background transparency)
- Theme: auto (follow system) / light / dark

### Git

- Auto-refresh interval: 2s / 5s / 10s / manual only
- Default base branch for PRs: main / master / custom
- Show git status in sidebar: on/off
- GitHub CLI path: auto-detect or manual

### Keyboard

- Full shortcut customization table
- Reset to defaults button

---

## Data Persistence

### App State (saved on quit, restored on launch)

```json
{
  "windowFrame": { "x": 100, "y": 100, "width": 1200, "height": 800 },
  "sidebarWidth": 240,
  "pathGroups": [
    {
      "id": "uuid-1",
      "path": "/Users/akm/projects/my-app",
      "displayName": null,
      "isCollapsed": false,
      "terminals": [
        {
          "id": "uuid-t1",
          "label": "Terminal 1",
          "splitLayout": null
        },
        {
          "id": "uuid-t2",
          "label": "Claude Code",
          "splitLayout": null
        }
      ]
    }
  ],
  "activeTerminalId": "uuid-t1",
  "splitLayout": {
    "type": "horizontal",
    "ratio": 0.5,
    "left": "uuid-t1",
    "right": "uuid-t2"
  }
}
```

- Stored in `~/Library/Application Support/TerminalWorkspace/state.json`
- Settings stored in `UserDefaults` (standard macOS approach)

---

## Current Build Status

**The app compiles and builds successfully with `swift build`.** All source files are in place and fully wired. The project uses pure SPM (no .xcodeproj) with SwiftTerm as the terminal engine. Run with `swift run Gho` or open `Package.swift` in Xcode.

### What Has Been Built

```
Gho/
├── Package.swift                                    (SPM, SwiftTerm dep, macOS 14+)
├── Sources/
│   ├── GhoApp.swift                                 (@main entry, bootstrap, persistence, git detection, FSEvents)
│   ├── ContentView.swift                            (root layout: sidebar + terminal + status bar + command palette)
│   ├── Models/
│   │   ├── AppState.swift                           (@Observable, path groups, split tree, pane navigation, font size)
│   │   ├── PathGroup.swift                          (@Observable, path + terminals + git state)
│   │   ├── TerminalSession.swift                    (session model + TerminalStatus enum)
│   │   ├── SplitNode.swift                          (recursive indirect enum for split pane tree)
│   │   ├── GitState.swift                           (@Observable, branch/staged/unstaged/ahead/behind)
│   │   ├── GitFileChange.swift                      (file change struct + GitChangeKind enum)
│   │   └── Settings.swift                           (AppSettings with all preferences)
│   ├── Services/
│   │   ├── Protocols/
│   │   │   ├── GitServiceProtocol.swift             (full protocol + GitDiff/DiffHunk/DiffLine types)
│   │   │   ├── FileWatcherProtocol.swift            (watch/stop with @MainActor callback)
│   │   │   ├── TerminalEngineProtocol.swift         (abstraction + processStarted + shellPid)
│   │   │   └── PersistenceServiceProtocol.swift     (PersistedState Codable + save/load protocol)
│   │   ├── GitCLIService.swift                      (shells out to git CLI, parses --porcelain=v2)
│   │   ├── FSEventsWatcher.swift                    (CoreServices FSEvents, 300ms debounce)
│   │   ├── TerminalSessionManager.swift             (@Observable, engine lifecycle, delegate routing, shell PID access)
│   │   └── JSONPersistenceService.swift             (JSON to ~/Library/Application Support/Gho/)
│   ├── Terminal/
│   │   ├── SwiftTermEngine.swift                    (TerminalEngineProtocol impl, processStarted flag, shellPid)
│   │   └── SwiftTermNSViewWrapper.swift             (NSViewRepresentable bridge for SwiftUI)
│   ├── Views/
│   │   ├── Sidebar/
│   │   │   ├── SidebarView.swift                    (path group list, Add Path with NSOpenPanel)
│   │   │   ├── PathGroupRow.swift                   (collapsible group, context menu, rename)
│   │   │   ├── TerminalRow.swift                    (status dot, click focus, context menu)
│   │   │   └── GitSectionView.swift                 (branch, counts, push/pull/stash/commit actions)
│   │   ├── Terminal/
│   │   │   ├── TerminalAreaView.swift               (renders SplitNode tree, tab bar, keyboard tab switching)
│   │   │   ├── TerminalPaneView.swift               (single pane, active border, starts shell on appear)
│   │   │   ├── SplitContainerView.swift             (recursive splits with draggable dividers)
│   │   │   └── TabBarView.swift                     (tab bar for multi-terminal single-pane mode)
│   │   ├── Git/
│   │   │   ├── BranchPickerView.swift               (popover, search, create new branch)
│   │   │   ├── ChangesListView.swift                (staged/unstaged files, stage/unstage/discard)
│   │   │   ├── DiffView.swift                       (unified diff with line numbers + colors)
│   │   │   ├── PRFormView.swift                     (PR form via gh CLI)
│   │   │   ├── CommitView.swift                     (commit message popover with stage-all option)
│   │   │   └── StashListView.swift                  (stash list with create/pop actions)
│   │   ├── SettingsView.swift                       (4-tab settings: General, Appearance, Git, Keyboard)
│   │   ├── StatusBarView.swift                      (24px bar: path, branch, counts)
│   │   └── CommandPaletteView.swift                 (Cmd+K overlay, fuzzy search, wired actions)
│   └── Utilities/
│       ├── PathFormatter.swift                      (URL extension: ~/... abbreviation)
│       ├── KeyboardShortcuts.swift                  (shortcut defs + GhoCommands + font size + pane nav)
│       └── ProcessDetector.swift                    (detect AI agents via real shell PIDs)
```

### Architecture Decisions Made

| Decision | Choice | Notes |
|----------|--------|-------|
| Build system | Pure SPM (`Package.swift`) | No .xcodeproj — open Package.swift in Xcode |
| Terminal engine | SwiftTerm via `TerminalEngineProtocol` | Abstracted behind protocol for future libghostty swap |
| Git operations | `git` CLI via `Process()` | Parses `git status --porcelain=v2 --branch` |
| File watching | FSEvents via CoreServices | Watches .git dirs with 300ms debounce |
| State management | Single `@Observable AppState` | Injected via SwiftUI `.environment()` |
| Split panes | Recursive `SplitNode` indirect enum | Value type, immutable mutations |
| Persistence | JSON to ~/Library/Application Support/Gho/ | Settings via UserDefaults |

### Key Patterns

- **Environment injection**: `@Environment(AppState.self)`, `@Environment(TerminalSessionManager.self)`
- **Bindable state**: `@Bindable var state = appState` for two-way bindings
- **Terminal abstraction**: `SwiftTermEngine` is the only file importing SwiftTerm — swap to libghostty by creating a new `TerminalEngineProtocol` conformer
- **Git service**: `GitCLIService` conforms to `GitServiceProtocol` — all methods are `async throws`
- **Bootstrap pattern**: `GhoApp.bootstrapApp()` runs on `.onAppear` — inits session manager, loads persisted state, detects git repos, starts FSEvents watchers

---

## What Has Been Wired (Completed)

### Phase 1 — Wiring & Runtime Fixes (DONE)

1. **Core app wiring** — `GhoApp.swift` bootstraps `TerminalSessionManager(appState:)` and `GitCLIService`, injects both into SwiftUI environment. `ContentView.swift` renders real `SidebarView`, `TerminalAreaView`, `StatusBarView`, and `CommandPaletteView` (all placeholders replaced). `GhoCommands` provides all menu bar shortcuts.

2. **FSEventsWatcher wired to git auto-refresh** — On path add, `GhoApp.detectGitAndWatch()` checks if path is a git repo, fetches initial status, and sets up FSEventsWatcher on the `.git` directory. Respects `settings.gitRefreshInterval` (0 = manual only).

3. **Git quick actions wired** — Push/Pull buttons in `GitSectionView` call `GitCLIService` with loading/error state. Commit button opens `CommitView` popover. Stash button opens `StashListView` popover.

4. **Persistence wired** — On launch: loads settings from UserDefaults, restores persisted state (path groups, terminals, split layout) from `~/Library/Application Support/Gho/state.json`. On quit (`willTerminateNotification`): saves state and settings.

5. **Git repo detection on path add** — `GhoApp.detectGitAndWatch()` runs for each path group, checks `isGitRepository`, fetches status, populates `group.gitState`.

6. **Terminal process start** — `TerminalPaneView.onAppear` calls `sessionManager.startProcess(for: terminalID)`. Double-start prevented by `processStarted` flag on `SwiftTermEngine`.

### Phase 2 — Features (DONE)

1. **Cmd+Option+Arrow** pane navigation — `AppState.navigatePane(direction:)` walks split tree, wired via `GhoCommands` menu items.
2. **Tab bar** — `TabBarView` shows when active path group has >1 terminal in single-pane mode. Status dots, close buttons, [+] to add terminal.
3. **Cmd+1-9** tab switching — handled via `onKeyPress` in `TerminalAreaView`.
4. **Cmd+Shift+]/[** next/previous tab — wired in `TerminalAreaView` key handler.
5. **Font size shortcuts** — Cmd+Plus/Minus/0 adjust `settings.terminalFontSize` and call `sessionManager.applySettings()`.
6. **Commit UI** — `CommitView` popover with message field, staged count, stage-all toggle.
7. **Stash list** — `StashListView` popover with create/pop actions.
8. **Process detection** — `ProcessDetector` wired to real shell PIDs via `SwiftTermEngine.shellPid` and `TerminalSessionManager.getShellPID(for:)`. Detects AI agents (claude, opencode, aider, etc.).
9. **Command palette actions** — Add Path opens NSOpenPanel, Switch Branch navigates to sidebar, Push calls git push.
10. **Settings view** — 4-tab `SettingsView` (General, Appearance, Git, Keyboard) wired to `AppSettings` and referenced from Settings scene.

## What Needs To Be Done Next

### Phase 3 — Runtime Testing & Polish

The app has not been runtime-tested. Launch with `swift run Gho` or Xcode and fix any runtime issues.

1. **Test the full terminal flow** — Add path → terminal created → shell starts → can type commands → split right/down → close pane → remove path group
2. **Animations**: smooth sidebar collapse/expand, split pane resize
3. **Error handling**: show user-facing alerts for git errors, process failures
4. **Cmd+Shift+Enter** maximize/restore pane toggle — wired in menu, verify runtime
5. **Cmd+F** find in terminal scrollback — `search()` in engine returns 0 (stub)
6. **Drag terminals between path groups** — not implemented
7. **URL clicking** in terminal (Cmd+click to open) — not implemented
8. **Window state restoration**: use `NSWindow` state restoration API
9. **Settings apply live**: when user changes font/theme in Settings, apply to all terminals immediately
10. **Edge cases**: disconnected git remotes, large repos, binary files in diff, empty repos

### Phase 4 — libghostty Migration (Optional, for maximum performance)

Replace SwiftTerm with libghostty for Metal GPU-accelerated rendering:

1. Build libghostty xcframework: `zig build -Demit-xcframework=true -Dxcframework-target=native`
2. Create module map and headers
3. Implement `GhosttyEngine: TerminalEngineProtocol`
4. Swap the factory in `TerminalSessionManager` from `SwiftTermEngine` to `GhosttyEngine`
5. No other files need to change (protocol abstraction)

Reference projects:
- **Calyx** — https://github.com/yuuichieguchi/Calyx (full macOS app using libghostty)
- **Ghostling** — https://github.com/ghostty-org/ghostling (minimal libghostty example)
- **cmux** — https://github.com/manaflow-ai/cmux (workspace management)
- **Ghostty** — https://github.com/ghostty-org/ghostty (libghostty source + API docs)

### Phase 5 — Distribution

1. Convert to Xcode project for app icon, entitlements, code signing
2. Accessibility: VoiceOver support for sidebar and terminal
3. Performance profiling with Instruments
4. Notarization for distribution
5. Auto-update mechanism (Sparkle framework)

---

## Non-Goals (Out of Scope)

- Code editor / text editor of any kind
- File tree / file browser (use terminal commands or Finder)
- Built-in AI integration (the AI runs in the terminal, not in the app)
- Windows or Linux support
- Plugin/extension system (keep it simple)
- Remote/SSH session management (use SSH from terminal directly)
- Integrated documentation viewer
