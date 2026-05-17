#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/R6 DPI Studio.app"
MACOS="$APP/Contents/MacOS"

rm -rf "$APP"
mkdir -p "$MACOS"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"

swiftc \
  "$ROOT/Sources/R6DPIApp.swift" \
  -o "$MACOS/R6DPIStudio" \
  -framework SwiftUI \
  -framework AppKit \
  -framework IOKit \
  -parse-as-library

echo "$APP"
