# FinderCut - Xcode Project Setup Guide

A macOS app that adds true Cmd+X / Cmd+V cut-and-paste for files in Finder, combining:
- **Keyboard shortcuts** (Cmd+X / Cmd+V) via CGEventTap
- **Right-click context menu** ("Cut" / "Paste Here") via Finder Sync Extension

## Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later
- Apple Developer account (free or paid)

## Step-by-Step Xcode Project Setup

### 1. Create the Main App Target

1. Open Xcode → **File > New > Project**
2. Select **macOS > App**
3. Configure:
   - **Product Name:** `FinderCut`
   - **Team:** Your Apple Developer team
   - **Organization Identifier:** `com.yourname` (e.g., `com.citroengames`)
   - **Interface:** SwiftUI
   - **Language:** Swift
4. Save to the `FinderCut/` directory (alongside these source files)
5. **Delete** the auto-generated `ContentView.swift` and `FinderCutApp.swift`
6. **Add existing files:** Drag all files from `FinderCut/` subfolder into the Xcode project navigator

### 2. Configure the Main App Target

#### Info.plist
- Set **LSUIElement** = `YES` (hides app from Dock, menu bar only)
- Use the provided `FinderCut/Info.plist`

#### Signing & Capabilities
1. Select the FinderCut target → **Signing & Capabilities**
2. Set **Team** and **Bundle Identifier** (e.g., `com.yourname.FinderCut`)
3. Click **+ Capability** → Add **App Groups**
   - Add group: `group.com.findercut.shared`
4. Click **+ Capability** → Add **App Sandbox** (should already be there)

#### Build Settings
- **macOS Deployment Target:** 13.0 (or 14.0 for best compatibility)
- **Code Signing Entitlements:** Point to `FinderCut/FinderCut.entitlements`

### 3. Add the Finder Sync Extension Target

1. **File > New > Target**
2. Select **macOS > Finder Sync Extension**
3. Configure:
   - **Product Name:** `FinderCutExtension`
   - **Bundle Identifier:** `com.yourname.FinderCut.FinderCutExtension`
   - **Embed in Application:** FinderCut
4. When prompted to activate the scheme, click **Activate**
5. **Delete** the auto-generated `FinderSync.swift` in the new target
6. **Add existing files:** Drag `FinderCutExtension/FinderSync.swift` into the extension target

#### Configure Extension Target

1. Select FinderCutExtension target → **Signing & Capabilities**
2. Click **+ Capability** → Add **App Groups**
   - Add the SAME group: `group.com.findercut.shared`
3. Ensure **App Sandbox** is enabled
4. Set **Code Signing Entitlements:** Point to `FinderCutExtension/FinderCutExtension.entitlements`

#### Info.plist for Extension
- Use the provided `FinderCutExtension/Info.plist`
- Verify `NSExtensionPrincipalClass` = `$(PRODUCT_MODULE_NAME).FinderSync`
- Verify `NSExtensionPointIdentifier` = `com.apple.FinderSync`

### 4. Update Bundle Identifiers

Make sure to update the App Group identifier in these files if you change it from `group.com.findercut.shared`:

- `FinderCut/State/SharedDefaults.swift` → `suiteName`
- `FinderCutExtension/FinderSync.swift` → `suiteName`
- `FinderCut/FinderCut.entitlements` → `com.apple.security.application-groups`
- `FinderCutExtension/FinderCutExtension.entitlements` → `com.apple.security.application-groups`

### 5. Build and Run

1. Select the **FinderCut** scheme (not the extension)
2. Press **Cmd+R** to build and run
3. The app appears in the **menu bar** (scissors icon)
4. macOS will prompt for **Accessibility permission** — grant it
5. Enable the Finder Extension:
   - Go to **System Settings > General > Login Items & Extensions**
   - Under **Finder Extensions**, enable **FinderCutExtension**

## Usage

### Keyboard Shortcuts (CGEventTap)
1. In Finder, select file(s)
2. Press **Cmd+X** (you'll hear a sound effect)
3. Navigate to the destination folder
4. Press **Cmd+V** — files are **moved** (not copied)

### Context Menu (Finder Sync Extension)
1. Right-click file(s) in Finder → select **Cut**
2. Navigate to the destination folder
3. Right-click empty space → select **Paste Here (Move N items)**
4. Files are moved to the current folder

### How It Works

**Keyboard shortcut flow:**
- Cmd+X is intercepted → the app simulates Cmd+C (copy) behind the scenes
- A "pending cut" flag is set
- On Cmd+V with pending cut → the app simulates Option+Cmd+V (Finder's native "Move Item Here")
- Files are moved by **Finder itself** — safe, with proper undo support

**Context menu flow:**
- "Cut" stores selected file paths in shared UserDefaults (App Groups)
- "Paste Here" uses `FileManager.moveItem()` to perform the move
- Handles name collisions by appending numbers

## Permissions Required

| Permission | Why | How to Grant |
|-----------|-----|-------------|
| Accessibility | CGEventTap needs to intercept keyboard events | System Settings > Privacy & Security > Accessibility |
| Finder Extension | Context menu integration | System Settings > General > Login Items & Extensions > Finder Extensions |

## Troubleshooting

### Cmd+X doesn't work
- Check that Accessibility permission is granted (menu bar icon shows status)
- Restart the app after granting Accessibility permission
- Ensure the app is enabled in the menu bar (toggle "Enabled")

### Context menu doesn't appear
- Enable the extension: System Settings > General > Login Items & Extensions
- On macOS Sequoia 15.2+, the setting moved to a new location in System Settings
- Try: `pluginkit -m -i com.yourname.FinderCut.FinderCutExtension` in Terminal

### Event tap stops working
- The system may disable event taps after inactivity. The app auto-re-enables them.
- If persistent, restart the app

## Architecture

```
FinderCut (Menu Bar App)
├── AppDelegate          ← Lifecycle, workspace notifications
├── EventTapManager      ← CGEventTap for Cmd+X/V interception
├── KeySimulator         ← Posts simulated Cmd+C and Opt+Cmd+V events
├── CutStateManager      ← Tracks pending cut state (shared via App Groups)
├── SharedDefaults       ← UserDefaults wrapper for App Groups IPC
├── AccessibilityChecker ← Checks/requests Accessibility permission
└── FinderDetector       ← Detects if Finder is frontmost

FinderCutExtension (Finder Sync Extension)
├── FinderSync           ← FIFinderSync subclass with context menus
└── Uses shared state from CutStateManager via App Groups
```

## Distribution Notes

### App Store
- Remove `com.apple.security.temporary-exception.files.absolute-path.read-write` from the extension entitlements
- The extension will only be able to move files the user explicitly selects
- The keyboard shortcut part works fine since Finder handles the actual move

### Direct Distribution (outside App Store)
- Keep the temporary file exception for broad file access
- Sign with Developer ID for notarization
- Users need to allow the app in System Settings > Privacy & Security
