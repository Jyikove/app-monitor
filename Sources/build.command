#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
APP_OUTPUT="${1:-../App monitor.app}"
BUILD_DIR="$(mktemp -d -t appoverview-build)"
trap 'rm -rf "$BUILD_DIR"' EXIT
mkdir -p "$APP_OUTPUT/Contents/MacOS" "$APP_OUTPUT/Contents/Resources"
xcrun clang -O2 -mmacosx-version-min=13.0 -c ProcessProbe.c -o "$BUILD_DIR/ProcessProbe.o"
xcrun swiftc -O -swift-version 5 -target arm64-apple-macosx13.0 -import-objc-header ProcessProbe.h \
    Monitor.swift App.swift "$BUILD_DIR/ProcessProbe.o" -framework AppKit -framework SwiftUI \
    -o "$APP_OUTPUT/Contents/MacOS/AppMonitor"
cp Info.plist "$APP_OUTPUT/Contents/Info.plist"
ICON_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" Info.plist)
cp "$ICON_NAME.icns" "$APP_OUTPUT/Contents/Resources/"
codesign --force --sign - "$APP_OUTPUT"
print "Built: $APP_OUTPUT"
