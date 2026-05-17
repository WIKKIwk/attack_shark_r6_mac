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

APP_SOURCES=(
  "$ROOT/Sources/App/R6DPIStudioApp.swift"
  "$ROOT/Sources/App/ContentView.swift"
  "$ROOT/Sources/ViewModels/R6ViewModel.swift"
  "$ROOT/Sources/Models/DPIStage.swift"
  "$ROOT/Sources/Models/SensorSettings.swift"
  "$ROOT/Sources/Models/R6Error.swift"
  "$ROOT/Sources/HID/R6HIDDevice.swift"
  "$ROOT/Sources/HID/R6HIDTransport.swift"
  "$ROOT/Sources/HID/R6Protocol.swift"
)

swiftc \
  "${APP_SOURCES[@]}" \
  -o "$MACOS/R6DPIStudio" \
  -framework SwiftUI \
  -framework AppKit \
  -framework IOKit \
  -parse-as-library

swiftc \
  "$ROOT/Sources/Helper/R6DPIHelper.swift" \
  -o "$MACOS/R6DPIHelper" \
  -framework IOKit

echo "$APP"
