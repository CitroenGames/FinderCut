# FinderCut

A macOS menu bar utility that adds true **cut-and-paste** (Cmd+X / Cmd+V) for files in Finder.

macOS Finder only supports copy-paste — to move files you need the obscure Option+Cmd+V shortcut. FinderCut fixes this by intercepting Cmd+X and Cmd+V to perform file moves naturally, just like on Windows or Linux.

## Features

- **Cmd+X / Cmd+V** — Cut and paste files using familiar keyboard shortcuts
- **Right-click context menu** — "Cut" and "Paste Here" options via Finder Sync Extension
- **Native file moves** — Uses Finder's own move operation, with full undo support
- **Menu bar app** — Runs quietly in the menu bar with a scissors icon
- **Sound feedback** — Optional sound effect on cut (configurable)
- **Smart activation** — Only active when Finder is the frontmost app

## Installation

### Build from source

Requires Xcode Command Line Tools (`xcode-select --install`).

```bash
# Build for your Mac's architecture
./build.sh

# Build universal binary (Intel + Apple Silicon)
./build.sh --universal

# Build and install to /Applications
./build.sh --install
```

### Run

```bash
open build/FinderCut.app
```

## Setup

After launching, two permissions are required:

| Permission | Why | Where to grant |
|---|---|---|
| **Accessibility** | Intercept keyboard shortcuts | System Settings > Privacy & Security > Accessibility |
| **Finder Extension** | Context menu integration | System Settings > General > Login Items & Extensions > Finder Extensions |

The app will prompt for Accessibility permission on first launch. To enable the Finder extension manually:

```bash
pluginkit -e use -i com.findercut.FinderCut.FinderCutExtension
```

## Usage

### Keyboard shortcuts
1. Select file(s) in Finder
2. Press **Cmd+X** (you'll hear a sound if enabled)
3. Navigate to the destination folder
4. Press **Cmd+V** — files are **moved**, not copied

### Context menu
1. Right-click file(s) > **Cut**
2. Navigate to the destination folder
3. Right-click empty space > **Paste Here**

## How it works

**Keyboard shortcut flow:**
- Cmd+X is intercepted via `CGEventTap` → simulates Cmd+C (copy) and sets a "pending cut" flag
- Cmd+V with a pending cut → simulates Option+Cmd+V (Finder's native "Move Item Here")
- The move is performed by Finder itself, so undo works normally

**Context menu flow:**
- "Cut" stores selected file paths in shared `UserDefaults` via App Groups
- "Paste Here" uses `FileManager.moveItem()` to move the files
- Name collisions are handled by appending a number

## Architecture

```
FinderCut (Menu Bar App)
├── AppDelegate          — Lifecycle, workspace notifications
├── EventTapManager      — CGEventTap for Cmd+X/V interception
├── KeySimulator         — Simulates Cmd+C and Option+Cmd+V
├── CutStateManager      — Pending cut state (shared via App Groups)
├── SharedDefaults       — UserDefaults wrapper for App Groups IPC
├── AccessibilityChecker — Checks/requests Accessibility permission
└── FinderDetector       — Detects if Finder is the frontmost app

FinderCutExtension (Finder Sync Extension)
└── FinderSync           — Context menus, toolbar button, file moves
```

## Build options

| Option | Description |
|---|---|
| `./build.sh` | Build for native architecture |
| `./build.sh --universal` | Build universal binary (arm64 + x86_64) |
| `./build.sh --install` | Build and install to /Applications |
| `./build.sh --clean` | Clean build directory before building |

Environment variables:

| Variable | Default | Description |
|---|---|---|
| `SIGNING_IDENTITY` | `-` (ad-hoc) | Code signing identity |
| `BUNDLE_ID` | `com.findercut.FinderCut` | App bundle identifier |

## Troubleshooting

**Cmd+X doesn't work**
- Check that Accessibility permission is granted (the menu bar icon shows status)
- Make sure the app is enabled via the menu bar toggle
- Restart the app after granting permission

**Context menu doesn't appear**
- Enable the Finder extension in System Settings > General > Login Items & Extensions
- Run `pluginkit -e use -i com.findercut.FinderCut.FinderCutExtension`

**Event tap stops working**
- macOS may disable event taps after inactivity — the app re-enables them automatically
- If it persists, restart the app

## Requirements

- macOS 15.0 (Sequoia) or later
- Xcode Command Line Tools

## License

See [LICENSE](LICENSE) for details.
