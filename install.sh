#!/bin/bash
# LoginToggle installer — builds from source and installs the app + CLI scripts.
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v swift >/dev/null 2>&1; then
    echo "error: Swift not found. Run:  xcode-select --install   (then rerun this script)" >&2
    exit 1
fi

echo "==> Building (release)"
swift build -c release

APP="$HOME/Applications/LoginToggle.app"
echo "==> Installing app to $APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/LoginToggle "$APP/Contents/MacOS/LoginToggle"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>LoginToggle</string>
	<key>CFBundleIdentifier</key><string>com.kartikkabadi.login-toggle</string>
	<key>CFBundleExecutable</key><string>LoginToggle</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.0</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>LSUIElement</key><true/>
	<key>NSAppleEventsUsageDescription</key><string>LoginToggle manages apps that open at login.</string>
</dict>
</plist>
PLIST

echo "==> Installing CLI scripts"
BIN="$HOME/.local/bin"
mkdir -p "$BIN"
cp scripts/login-off scripts/login-on "$BIN/"
chmod +x "$BIN/login-off" "$BIN/login-on"

echo "==> Launching"
killall LoginToggle 2>/dev/null || true
sleep 1
open "$APP"
sleep 1

if pgrep -x LoginToggle >/dev/null; then
    echo "done. LoginToggle is running — look for the power icon in your menu bar."
    echo "CLI:  login-off (turn everything off)   login-on (restore)"
else
    echo "warning: app did not stay up. Try running it directly:" >&2
    echo "  '$APP/Contents/MacOS/LoginToggle'" >&2
    exit 1
fi
