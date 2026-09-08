#!/bin/bash
# LoginToggle installer — builds from source and installs the app + CLI scripts.
# Works both ways:  bash install.sh   (inside a checkout)   or   curl -fsSL https://raw.githubusercontent.com/kartikkabadi/login-toggle/main/install.sh | bash
set -euo pipefail
cd "$(dirname "$0")" 2>/dev/null || true

if ! command -v swift >/dev/null 2>&1; then
    echo "error: Swift not found. Run:  xcode-select --install   (then rerun this script)" >&2
    exit 1
fi
if ! command -v git >/dev/null 2>&1; then
    echo "error: git not found. Run:  xcode-select --install   (then rerun this script)" >&2
    exit 1
fi

# Piped or run outside a checkout: clone the source first.
if [ ! -f Package.swift ]; then
    SRC="$HOME/.local/share/login-toggle/src"
    if [ -d "$SRC/.git" ]; then
        echo "==> Updating source in $SRC"
        git -C "$SRC" fetch --depth 1 origin main
        git -C "$SRC" reset --hard origin/main
    else
        echo "==> Cloning source to $SRC"
        git clone --depth 1 https://github.com/kartikkabadi/login-toggle "$SRC"
    fi
    cd "$SRC"
fi

echo "==> Building (release)"
swift build -c release

APP="$HOME/Applications/LoginToggle.app"
echo "==> Installing app to $APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/LoginToggle "$APP/Contents/MacOS/LoginToggle"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
echo -n "APPL????" > "$APP/Contents/PkgInfo"
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>LoginToggle</string>
	<key>CFBundleIdentifier</key><string>com.kartikkabadi.login-toggle</string>
	<key>CFBundleExecutable</key><string>LoginToggle</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>0.0.1</string>
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
