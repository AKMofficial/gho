#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="/tmp/ghostty-build"
FRAMEWORK_DIR="$PROJECT_DIR/Frameworks"

echo "==> Cloning Ghostty..."
rm -rf "$BUILD_DIR"
git clone --depth 1 https://github.com/ghostty-org/ghostty.git "$BUILD_DIR"

echo "==> Building GhosttyKit.xcframework..."
cd "$BUILD_DIR"
zig build -Demit-xcframework=true -Dxcframework-target=native -Doptimize=ReleaseFast

echo "==> Copying xcframework to project..."
mkdir -p "$FRAMEWORK_DIR"
cp -R zig-out/GhosttyKit.xcframework "$FRAMEWORK_DIR/"

echo "==> Done! GhosttyKit.xcframework is at $FRAMEWORK_DIR/GhosttyKit.xcframework"
