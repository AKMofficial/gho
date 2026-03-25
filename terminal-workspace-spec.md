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

## AI Build Instructions

This section tells the AI how to build this project step by step.

### Phase 1 — Project Skeleton + Single Terminal (Day 1)

**Goal:** A macOS app with a window that shows a working terminal using libghostty.

1. Create a new Xcode project (macOS App, SwiftUI lifecycle)
2. Set up the project with Swift Package Manager
3. Integrate libghostty as a C library dependency
   - Reference: https://github.com/ghostty-org/ghostty (libghostty)
   - Reference: https://github.com/ghostty-org/ghostling (minimal example)
   - Reference: https://github.com/yuuichieguchi/Calyx (full macOS app using libghostty)
4. Create a `TerminalView` that wraps libghostty's Metal surface in an `NSViewRepresentable`
5. Set up PTY (pseudo-terminal) to spawn the user's default shell
6. Wire keyboard input → PTY input, PTY output → libghostty → Metal render
7. Result: a window with one functional terminal that can run commands

**Key files to create:**

```
TerminalWorkspace/
├── TerminalWorkspaceApp.swift          (app entry point)
├── Models/
│   ├── PathGroup.swift                 (data model)
│   ├── TerminalSession.swift           (data model)
│   └── AppState.swift                  (observable app state)
├── Views/
│   ├── ContentView.swift               (main layout: sidebar + terminal area)
│   ├── Sidebar/
│   │   ├── SidebarView.swift           (full sidebar)
│   │   ├── PathGroupView.swift         (one path group)
│   │   ├── TerminalRowView.swift       (one terminal row)
│   │   └── GitStatusView.swift         (git section in a group)
│   ├── Terminal/
│   │   ├── TerminalContainerView.swift (manages splits/tabs)
│   │   ├── TerminalView.swift          (wraps libghostty NSView)
│   │   └── SplitPaneView.swift         (recursive split layout)
│   ├── Git/
│   │   ├── BranchPickerView.swift      (branch selection popover)
│   │   ├── ChangesListView.swift       (staged/unstaged file list)
│   │   ├── DiffView.swift              (file diff display)
│   │   └── PRFormView.swift            (create pull request form)
│   ├── StatusBarView.swift             (bottom status bar)
│   ├── CommandPaletteView.swift        (Cmd+K palette)
│   └── SettingsView.swift              (preferences window)
├── Services/
│   ├── TerminalSessionManager.swift    (create/destroy terminal sessions)
│   ├── GitService.swift                (all git operations via libgit2)
│   ├── FileWatcherService.swift        (FSEvents watcher for git changes)
│   └── PersistenceService.swift        (save/restore app state)
├── Helpers/
│   ├── KeyboardShortcuts.swift         (shortcut definitions)
│   └── PathFormatter.swift             (~/... path abbreviation)
└── Bridge/
    └── LibGhostty.swift                (Swift wrapper around C-ABI)
```

### Phase 2 — Sidebar + Path Groups (Day 2)

**Goal:** Sidebar with path groups, add/remove paths, multiple terminals per group.

1. Implement `AppState` as `@Observable` class holding array of `PathGroup`
2. Build `SidebarView` with `List` in `.sidebar` style
3. Implement "Add Path" button → `NSOpenPanel` folder picker
4. Each `PathGroup` shows its terminals as child rows
5. Implement [+] button per group → creates new `TerminalSession` in that directory
6. Click terminal row → sets it as active in the terminal area
7. Implement right-click context menus on paths and terminals
8. Wire up `Cmd+Shift+O` (add path) and `Cmd+T` (new terminal)

### Phase 3 — Split Panes (Day 3)

**Goal:** Side-by-side and vertical terminal splits.

1. Build `SplitPaneView` as a recursive structure (each split has two children, which can be terminals or further splits)
2. Implement draggable dividers using `GeometryReader` + gesture recognizers
3. Wire `Cmd+D` (split right) and `Cmd+Shift+D` (split down)
4. Implement `Cmd+Option+Arrow` navigation between panes
5. Active pane highlight (subtle border)
6. `Cmd+W` to close pane, collapsing the split
7. `Cmd+Shift+Enter` to maximize/restore

### Phase 4 — Git Integration (Day 4-5)

**Goal:** Full git status, staging, branching, push/PR in the sidebar.

1. Integrate libgit2 (via SwiftGit2 or direct C bindings)
2. Implement `GitService` with methods:
   - `getStatus(path:)` → staged, unstaged, untracked file lists
   - `getDiff(path:file:staged:)` → diff content for a file
   - `getBranches(path:)` → local branch list
   - `switchBranch(path:branch:)` → checkout branch
   - `stageFile(path:file:)` / `unstageFile(path:file:)`
   - `stageAll(path:)` / `unstageAll(path:)`
   - `commit(path:message:)` → create commit
   - `push(path:)` → push to remote
   - `pull(path:)` → pull from remote
3. Implement `FileWatcherService` watching `.git` directories for changes → auto-refresh status
4. Build `GitStatusView` in sidebar showing branch + counts
5. Build `ChangesListView` as expandable section with file list
6. Build `DiffView` as a popover/sheet showing syntax-highlighted diffs
7. Build `BranchPickerView` as a popover with search
8. Implement quick action buttons: Push, Pull, PR, Stash
9. PR creation: shell out to `gh pr create` via Process()

### Phase 5 — Polish + UX (Day 6-7)

**Goal:** Status bar, command palette, settings, session persistence, and polish.

1. Build `StatusBarView` at bottom of window
2. Build `CommandPaletteView` (Cmd+K) with fuzzy search
3. Build `SettingsView` with tabs (General, Appearance, Git, Keyboard)
4. Implement `PersistenceService`:
   - Save state to JSON on quit (`applicationWillTerminate`)
   - Restore state on launch
   - Save terminal scrollback (optional, can be large)
5. Implement drag-to-reorder in sidebar (path groups and terminals)
6. Implement terminal rename (double-click label)
7. Process status detection (idle/running/error/AI agent)
8. Window restoration (NSWindow state restoration)
9. URL clicking in terminal (Cmd+click to open)
10. Find in terminal scrollback (Cmd+F)

### Phase 6 — Refinement (Week 2)

1. Animations: smooth sidebar collapse/expand, pane resize
2. Performance: profile with Instruments, optimize git polling frequency
3. Edge cases: handle disconnected git remotes, large repos, binary files in diff
4. Accessibility: VoiceOver support for sidebar
5. Notarization: sign and notarize for distribution
6. Auto-update mechanism (Sparkle framework)

---

## Reference Projects for AI

When building, the AI should study these codebases for patterns:

1. **Calyx** — https://github.com/yuuichieguchi/Calyx
   - How to integrate libghostty in a Swift/macOS app
   - How to build a git source control sidebar
   - How to manage terminal sessions with libghostty

2. **Ghostling** — https://github.com/ghostty-org/ghostling
   - Minimal example of using libghostty's C-ABI
   - Terminal rendering pipeline basics

3. **cmux** — https://github.com/manaflow-ai/cmux
   - Workspace management for AI terminal sessions
   - Process detection (identifying AI agents)

4. **Ghostty** — https://github.com/ghostty-org/ghostty
   - libghostty API documentation and headers
   - Terminal configuration options

---

## Non-Goals (Out of Scope)

- Code editor / text editor of any kind
- File tree / file browser (use terminal commands or Finder)
- Built-in AI integration (the AI runs in the terminal, not in the app)
- Windows or Linux support
- Plugin/extension system (keep it simple)
- Remote/SSH session management (use SSH from terminal directly)
- Integrated documentation viewer
