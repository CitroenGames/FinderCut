#!/bin/bash
# build.sh — Build FinderCut from source using swiftc + manual bundle assembly
# Requires: Xcode Command Line Tools (xcode-select --install)
#
# Usage:
#   ./build.sh              Build for native architecture
#   ./build.sh --universal  Build universal binary (arm64 + x86_64)
#   ./build.sh --install    Build and copy to /Applications
#   ./build.sh --clean      Remove build directory before building
#
# Environment variables:
#   SIGNING_IDENTITY  Code signing identity (default: "-" for ad-hoc)
#   BUNDLE_ID         Main app bundle ID (default: "com.findercut.FinderCut")

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────

APP_NAME="FinderCut"
EXT_NAME="FinderCutExtension"
BUNDLE_ID="${BUNDLE_ID:-com.findercut.FinderCut}"
EXT_BUNDLE_ID="${BUNDLE_ID}.FinderCutExtension"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
DEPLOYMENT_TARGET="15.0"

# Paths (relative to this script's directory)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/FinderCut"
EXT_SRC_DIR="$SCRIPT_DIR/FinderCutExtension"
BUILD_DIR="$SCRIPT_DIR/build"

APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
EXT_BUNDLE="$APP_CONTENTS/PlugIns/$EXT_NAME.appex"
EXT_CONTENTS="$EXT_BUNDLE/Contents"

# SDK
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"

# ─── Parse Arguments ─────────────────────────────────────────────────────────

UNIVERSAL=false
INSTALL=false
CLEAN=false

for arg in "$@"; do
    case "$arg" in
        --universal) UNIVERSAL=true ;;
        --install)   INSTALL=true ;;
        --clean)     CLEAN=true ;;
        --help|-h)
            echo "Usage: $0 [--universal] [--install] [--clean]"
            echo ""
            echo "Options:"
            echo "  --universal  Build universal binary (arm64 + x86_64)"
            echo "  --install    Copy built app to /Applications"
            echo "  --clean      Remove build directory before building"
            echo ""
            echo "Environment:"
            echo "  SIGNING_IDENTITY  Code signing identity (default: - for ad-hoc)"
            echo "  BUNDLE_ID         App bundle identifier (default: com.findercut.FinderCut)"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            exit 1
            ;;
    esac
done

# ─── Preflight Checks ───────────────────────────────────────────────────────

echo "==> Checking prerequisites..."

if ! command -v swiftc &>/dev/null; then
    echo "ERROR: swiftc not found. Install Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

if ! command -v codesign &>/dev/null; then
    echo "ERROR: codesign not found. Install Xcode Command Line Tools."
    exit 1
fi

if [ ! -d "$SDK_PATH" ]; then
    echo "ERROR: macOS SDK not found at $SDK_PATH"
    exit 1
fi

echo "    swiftc:  $(swiftc --version 2>&1 | head -1)"
echo "    SDK:     $SDK_PATH"
echo "    Signing: $SIGNING_IDENTITY"

# ─── Clean ───────────────────────────────────────────────────────────────────

if [ "$CLEAN" = true ] && [ -d "$BUILD_DIR" ]; then
    echo "==> Cleaning build directory..."
    rm -rf "$BUILD_DIR"
fi

# ─── Create Bundle Structure ─────────────────────────────────────────────────

echo "==> Creating bundle structure..."

mkdir -p "$APP_CONTENTS/MacOS"
mkdir -p "$APP_CONTENTS/Resources"
mkdir -p "$EXT_CONTENTS/MacOS"
mkdir -p "$EXT_CONTENTS/Resources"

# ─── Collect Source Files ─────────────────────────────────────────────────────

APP_SOURCES=(
    "$SRC_DIR/App/FinderCutApp.swift"
    "$SRC_DIR/App/AppDelegate.swift"
    "$SRC_DIR/EventTap/EventTapManager.swift"
    "$SRC_DIR/EventTap/KeySimulator.swift"
    "$SRC_DIR/State/CutStateManager.swift"
    "$SRC_DIR/State/SharedDefaults.swift"
    "$SRC_DIR/Utilities/AccessibilityChecker.swift"
    "$SRC_DIR/Utilities/FinderDetector.swift"
)

EXT_SOURCES=(
    "$EXT_SRC_DIR/FinderSync.swift"
)

# Verify all source files exist
for src in "${APP_SOURCES[@]}" "${EXT_SOURCES[@]}"; do
    if [ ! -f "$src" ]; then
        echo "ERROR: Source file not found: $src"
        exit 1
    fi
done

# ─── Build Function ──────────────────────────────────────────────────────────

build_target() {
    local target_name="$1"
    local module_name="$2"
    local output_path="$3"
    local arch="$4"
    shift 4
    local extra_flags=("$@")

    echo "    Compiling $target_name ($arch)..."

    swiftc \
        -module-name "$module_name" \
        -target "${arch}-apple-macosx${DEPLOYMENT_TARGET}" \
        -sdk "$SDK_PATH" \
        -O \
        -o "$output_path" \
        "${extra_flags[@]}"
}

# ─── Compile Main App ────────────────────────────────────────────────────────

echo "==> Compiling main app..."

APP_FRAMEWORKS=(
    -framework AppKit
    -framework SwiftUI
    -framework CoreGraphics
    -framework ApplicationServices
    -framework ServiceManagement
)

if [ "$UNIVERSAL" = true ]; then
    # Build for both architectures and merge with lipo
    build_target "FinderCut" "FinderCut" "$BUILD_DIR/FinderCut_arm64" "arm64" \
        "${APP_FRAMEWORKS[@]}" "${APP_SOURCES[@]}"
    build_target "FinderCut" "FinderCut" "$BUILD_DIR/FinderCut_x86_64" "x86_64" \
        "${APP_FRAMEWORKS[@]}" "${APP_SOURCES[@]}"

    echo "    Creating universal binary..."
    lipo -create \
        "$BUILD_DIR/FinderCut_arm64" \
        "$BUILD_DIR/FinderCut_x86_64" \
        -output "$APP_CONTENTS/MacOS/$APP_NAME"
    rm "$BUILD_DIR/FinderCut_arm64" "$BUILD_DIR/FinderCut_x86_64"
else
    ARCH="$(uname -m)"
    build_target "FinderCut" "FinderCut" "$APP_CONTENTS/MacOS/$APP_NAME" "$ARCH" \
        "${APP_FRAMEWORKS[@]}" "${APP_SOURCES[@]}"
fi

# ─── Compile Extension ───────────────────────────────────────────────────────

echo "==> Compiling Finder Sync extension..."

EXT_FLAGS=(
    -parse-as-library
    -framework Cocoa
    -framework FinderSync
    -Xlinker -e -Xlinker _NSExtensionMain
    -Xlinker -application_extension
)

if [ "$UNIVERSAL" = true ]; then
    build_target "FinderCutExtension" "FinderCutExtension" "$BUILD_DIR/FinderCutExtension_arm64" "arm64" \
        "${EXT_FLAGS[@]}" "${EXT_SOURCES[@]}"
    build_target "FinderCutExtension" "FinderCutExtension" "$BUILD_DIR/FinderCutExtension_x86_64" "x86_64" \
        "${EXT_FLAGS[@]}" "${EXT_SOURCES[@]}"

    echo "    Creating universal binary..."
    lipo -create \
        "$BUILD_DIR/FinderCutExtension_arm64" \
        "$BUILD_DIR/FinderCutExtension_x86_64" \
        -output "$EXT_CONTENTS/MacOS/$EXT_NAME"
    rm "$BUILD_DIR/FinderCutExtension_arm64" "$BUILD_DIR/FinderCutExtension_x86_64"
else
    ARCH="$(uname -m)"
    build_target "FinderCutExtension" "FinderCutExtension" "$EXT_CONTENTS/MacOS/$EXT_NAME" "$ARCH" \
        "${EXT_FLAGS[@]}" "${EXT_SOURCES[@]}"
fi

# ─── Process Info.plist Files ─────────────────────────────────────────────────

echo "==> Processing Info.plist files..."

sed -e "s/\$(EXECUTABLE_NAME)/$APP_NAME/g" \
    -e "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/$BUNDLE_ID/g" \
    -e "s/\$(MACOSX_DEPLOYMENT_TARGET)/$DEPLOYMENT_TARGET/g" \
    "$SRC_DIR/Info.plist" > "$APP_CONTENTS/Info.plist"

sed -e "s/\$(EXECUTABLE_NAME)/$EXT_NAME/g" \
    -e "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/$EXT_BUNDLE_ID/g" \
    -e "s/\$(MACOSX_DEPLOYMENT_TARGET)/$DEPLOYMENT_TARGET/g" \
    -e "s/\$(PRODUCT_MODULE_NAME)/$EXT_NAME/g" \
    "$EXT_SRC_DIR/Info.plist" > "$EXT_CONTENTS/Info.plist"

# ─── Code Signing ────────────────────────────────────────────────────────────

echo "==> Code signing..."

# Sign extension first (inner), then app (outer)
echo "    Signing extension..."
codesign --force --sign "$SIGNING_IDENTITY" \
    --entitlements "$EXT_SRC_DIR/FinderCutExtension.entitlements" \
    "$EXT_BUNDLE"

echo "    Signing app..."
codesign --force --sign "$SIGNING_IDENTITY" \
    --entitlements "$SRC_DIR/FinderCut.entitlements" \
    "$APP_BUNDLE"

# ─── Verify ──────────────────────────────────────────────────────────────────

echo "==> Verifying..."

codesign --verify --deep --strict "$APP_BUNDLE" 2>&1 && \
    echo "    Code signature: OK" || \
    echo "    WARNING: Code signature verification failed (expected with ad-hoc signing)"

echo ""
echo "==> Build complete: $APP_BUNDLE"
echo ""

# ─── Install (optional) ──────────────────────────────────────────────────────

if [ "$INSTALL" = true ]; then
    echo "==> Installing to /Applications..."
    if [ -d "/Applications/$APP_NAME.app" ]; then
        echo "    Removing existing installation..."
        rm -rf "/Applications/$APP_NAME.app"
    fi
    cp -R "$APP_BUNDLE" "/Applications/"
    echo "    Installed to /Applications/$APP_NAME.app"
    echo ""
fi

# ─── Post-Build Instructions ─────────────────────────────────────────────────

cat <<'INSTRUCTIONS'
┌─────────────────────────────────────────────────────────────────┐
│                    FinderCut - Post-Build                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Run the app:                                                │
│     open build/FinderCut.app                                    │
│                                                                 │
│  2. Grant Accessibility permission when prompted:               │
│     System Settings > Privacy & Security > Accessibility        │
│     → Enable FinderCut                                          │
│                                                                 │
│  3. Enable the Finder extension:                                │
│     System Settings > General > Login Items & Extensions        │
│     → Finder Extensions → Enable FinderCutExtension             │
│                                                                 │
│     Or via terminal:                                            │
│     pluginkit -e use -i com.findercut.FinderCut.FinderCutExtension │
│                                                                 │
│  4. Usage:                                                      │
│     • Cmd+X to cut files in Finder                              │
│     • Cmd+V to paste (move) files                               │
│     • Right-click for Cut / Paste Here context menu              │
│                                                                 │
│  Note: On macOS Sequoia 15+ / Tahoe 26+, Accessibility          │
│  permission may need to be re-authorized monthly or after        │
│  reboots. This is a system-wide policy, not specific to          │
│  FinderCut.                                                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
INSTRUCTIONS
