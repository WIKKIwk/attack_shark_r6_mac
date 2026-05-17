#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/R6 DPI Studio.app"
MACOS="$APP/Contents/MacOS"
RESOURCES="$APP/Contents/Resources"

rm -rf "$APP"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/R6DPI.icns" "$RESOURCES/R6DPI.icns"

swiftc \
  "$ROOT/Sources/R6DPIApp.swift" \
  -o "$MACOS/R6DPIStudio" \
  -framework SwiftUI \
  -framework AppKit \
  -framework IOKit \
  -parse-as-library

swiftc \
  "$ROOT/Sources/R6DPIHelper.swift" \
  -o "$MACOS/R6DPIHelper" \
  -framework IOKit

echo "$APP"
