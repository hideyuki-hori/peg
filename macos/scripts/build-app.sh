#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release

APP="dist/Peg.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/Peg" "$APP/Contents/MacOS/Peg"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo "$APP"
