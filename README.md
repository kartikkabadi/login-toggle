<p align="center"><img src="docs/icon.png" width="128" alt="LoginToggle icon"></p>

# LoginToggle

One button to turn off every app that opens at login on macOS — and one click to turn it all back on.

No background daemon. A 150-line SwiftUI menu bar app plus two shell scripts.

## Give this to your agent

Copy the block below into Claude Code, Cursor, Codex, or any agent with shell access on your Mac. It will install and verify everything.

```text
Install LoginToggle (https://github.com/kartikkabadi/login-toggle) on this Mac:

1. Run: curl -fsSL https://raw.githubusercontent.com/kartikkabadi/login-toggle/main/install.sh | bash
   It clones the source, builds the app with Swift Package Manager, installs
   LoginToggle.app into ~/Applications, and installs two CLI scripts,
   login-off and login-on, into ~/.local/bin.
2. If `swift` or `git` is not found, run `xcode-select --install` first, wait
   for it to finish, then run the command again.
3. Verify: `pgrep -fl LoginToggle` shows a process, and a power icon appears in
   the menu bar (top right).
4. When done, tell me how to use it.

Do not click "Turn all off" — just install and verify.
```

## Install it yourself

One line (builds from source, handles everything):

```bash
curl -fsSL https://raw.githubusercontent.com/kartikkabadi/login-toggle/main/install.sh | bash
```

Or clone and run it yourself:

```bash
git clone https://github.com/kartikkabadi/login-toggle
cd login-toggle
./install.sh
```

Requirements: macOS 13+ and Xcode Command Line Tools (`xcode-select --install`).

## Use it

- Click the power icon in your menu bar. You get the full list: every login item and every launch agent that runs at login, each marked `on` or `off`.
- **Turn all off** — saves the current state, then stops launch agents immediately and removes login items. Nothing auto-starts at your next login.
- **Restore** — puts everything back and starts the agents again.
- In a terminal: `login-off` and `login-on`.
- **Update** — pulls the latest version from GitHub and reinstalls in place.

## What gets turned off

| Mechanism | Covered | Notes |
|---|---|---|
| Login items (System Settings > Login Items > Open at Login) | yes | listed, removed, restored by path |
| Launch agents in `~/Library/LaunchAgents` and `/Library/LaunchAgents` | yes | only ones with `RunAtLoad` or `KeepAlive`; stopped with `launchctl bootout`, disabled persistently with `launchctl disable` |
| "Allow in the Background" items (SMAppService, macOS 13+) | no | Apple provides no public API; manage in System Settings |
| Apple's own `com.apple.*` agents | never | left alone on purpose |
| LaunchDaemons (system services) | never | out of scope |

## Undo

Everything is reversible. State is saved to `~/.local/state/login-toggle/` before anything is touched, so **Restore** / `login-on` works even after a reboot. Removing a login item only affects the next login; apps already open stay open.

## Uninstall

```bash
login-on            # restore everything first
rm -rf ~/Applications/LoginToggle.app ~/.local/bin/login-off ~/.local/bin/login-on ~/.local/state/login-toggle
```

## How it works

- Login items are read and removed through System Events (AppleScript); restore re-adds them by saved path.
- Launch agents are found by scanning the two LaunchAgents folders and parsing each plist for `Label`, `RunAtLoad`, and `KeepAlive`. `launchctl bootout` stops them now; `launchctl disable` writes to launchd's persistent disabled database, so they stay off across reboots.
- The menu bar app shells out to the same two scripts, so the menu bar and the CLI always behave identically.

Known limit: items registered with SMAppService ("Allow in the Background") have no public toggle API, so LoginToggle does not list them. The apps that open windows at login — the annoying ones — are all covered.

## License

MIT
