#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/R6 DPI Studio.app"
DMG_ROOT="$ROOT/build/dmg-root"
DMG="$ROOT/build/R6-DPI-Studio.dmg"

if [[ ! -d "$APP" ]]; then
  "$ROOT/build.sh"
fi

rm -rf "$DMG_ROOT" "$DMG"
mkdir -p "$DMG_ROOT"

cp -R "$APP" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create \
  -volname "R6 DPI Studio" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG"

echo "$DMG"
