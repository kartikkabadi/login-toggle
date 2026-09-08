import SwiftUI
import Darwin
import LoginToggleCore

private let HOME = FileManager.default.homeDirectoryForCurrentUser.path
private let OFF = HOME + "/.local/bin/login-off"
private let ON = HOME + "/.local/bin/login-on"
private let STATE = HOME + "/.local/state/login-toggle"

func runCmd(_ launchPath: String, _ args: [String]) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: launchPath)
    p.arguments = args
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = pipe
    do { try p.run() } catch { return "" }
    p.waitUntilExit()
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
}

// Runs an AppleScript source via `osascript -`, passing args through to the
// run handler. Paths and names travel as argv, never interpolated into the
// script source.
func runAppleScript(_ source: String, _ args: [String] = []) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    p.arguments = ["-"] + args
    let inPipe = Pipe()
    inPipe.fileHandleForWriting.write(source.data(using: .utf8)!)
    inPipe.fileHandleForWriting.closeFile()
    p.standardInput = inPipe
    let outPipe = Pipe()
    p.standardOutput = outPipe
    p.standardError = outPipe
    do { try p.run() } catch { return "" }
    p.waitUntilExit()
    return String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
}

private let enumerateScript = """
tell application "System Events"
	set lis to every login item
	if (count of lis) is 0 then return ""
	set acc to ""
	repeat with li in lis
		set p to path of li
		if p is missing value then set p to "-"
		set acc to acc & (name of li) & (ASCII character 9) & p & linefeed
	end repeat
	return acc
end tell
"""

struct Row: Identifiable {
    let id: String
    let name: String
    let detail: String
    let isAgent: Bool
    let on: Bool
    let canEnable: Bool
}

final class Model: ObservableObject {
    @Published var loginRows: [Row] = []
    @Published var agentRows: [Row] = []
    @Published var busy = false

    private var savedItems: [(String, String)] {
        guard let raw = try? String(contentsOfFile: STATE + "/login-items.tsv", encoding: .utf8) else { return [] }
        return raw.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count == 2 else { return nil }
            return (String(parts[0]), String(parts[1]))
        }
    }

    private func saveItem(_ name: String, _ path: String) {
        try? FileManager.default.createDirectory(atPath: STATE, withIntermediateDirectories: true)
        let file = STATE + "/login-items.tsv"
        var existing = (try? String(contentsOfFile: file, encoding: .utf8)) ?? ""
        if !existing.contains("\(name)\t\(path)") {
            existing += "\(name)\t\(path)\n"
            try? existing.write(toFile: file, atomically: true, encoding: .utf8)
        }
    }

    private func forgetItem(_ name: String) {
        let file = STATE + "/login-items.tsv"
        guard var lines = try? String(contentsOfFile: file, encoding: .utf8).split(separator: "\n") else { return }
        lines = lines.filter { !$0.hasPrefix("\(name)\t") }
        try? lines.joined(separator: "\n").write(toFile: file, atomically: true, encoding: .utf8)
    }

    func refresh() {
        var rows: [Row] = []
        let tsv = runAppleScript(enumerateScript)
        var liveNames: Set<String> = []
        for line in tsv.split(separator: "\n") {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let n = String(parts[0])
            let p = String(parts[1]) == "missing value" ? "-" : String(parts[1])
            guard n != "missing value", hasVisibleName(n) else { continue }
            liveNames.insert(n)
            rows.append(Row(id: "li-\(p)", name: n, detail: p == "-" ? "" : p, isAgent: false, on: true, canEnable: true))
        }
        for (n, p) in savedItems where !liveNames.contains(n) && n != "missing value" && hasVisibleName(n) {
            rows.append(Row(id: "off-\(n)-\(p)", name: n, detail: (p == "-" || p.isEmpty) ? "" : p, isAgent: false, on: false, canEnable: p != "-" && !p.isEmpty))
        }
        loginRows = rows

        var agents: [Row] = []
        let db = runCmd("/bin/launchctl", ["print-disabled", "gui/\(getuid())"])
        let fm = FileManager.default
        for dir in [fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents"),
                    URL(fileURLWithPath: "/Library/LaunchAgents")] {
            guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for f in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where f.pathExtension == "plist" {
                guard let data = try? Data(contentsOf: f),
                      let p = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any],
                      let label = p["Label"] as? String else { continue }
                if label.hasPrefix("com.apple.") { continue }
                let runAtLoad = (p["RunAtLoad"] as? Bool) ?? false
                let keepAlive = p["KeepAlive"] != nil
                guard runAtLoad || keepAlive else { continue }
                let off = db.split(separator: "\n").contains { $0.contains(label) && $0.hasSuffix("disabled") }
                agents.append(Row(id: label, name: label, detail: "", isAgent: true, on: !off, canEnable: true))
            }
        }
        agentRows = agents
    }

    func toggle(_ row: Row) {
        busy = true
        DispatchQueue.global().async {
            if row.isAgent {
                if row.on {
                    _ = runCmd("/bin/launchctl", ["bootout", "gui/\(getuid())/\(row.id)"])
                    _ = runCmd("/bin/launchctl", ["disable", "gui/\(getuid())/\(row.id)"])
                } else {
                    _ = runCmd("/bin/launchctl", ["enable", "gui/\(getuid())/\(row.id)"])
                    for d in ["\(HOME)/Library/LaunchAgents", "/Library/LaunchAgents"] {
                        let p = "\(d)/\(row.id).plist"
                        if FileManager.default.fileExists(atPath: p) {
                            _ = runCmd("/bin/launchctl", ["bootstrap", "gui/\(getuid())", p])
                        }
                    }
                }
            } else if row.on {
                self.saveItem(row.name, row.detail.isEmpty ? "-" : row.detail)
                if row.detail.isEmpty {
                    _ = runAppleScript("""
                        on run argv
                        set n to item 1 of argv
                        tell application "System Events" to delete (every login item whose name is n)
                        end run
                        """, [row.name])
                } else {
                    _ = runAppleScript("""
                        on run argv
                        set p to item 1 of argv
                        tell application "System Events" to delete (every login item whose path is p)
                        end run
                        """, [row.detail])
                }
            } else if row.canEnable {
                _ = runAppleScript("""
                    on run argv
                    set p to item 1 of argv
                    tell application "System Events" to make login item at end with properties {path:p, hidden:false}
                    end run
                    """, [row.detail])
                self.forgetItem(row.name)
            }
            DispatchQueue.main.async {
                self.refresh()
                self.busy = false
            }
        }
    }

    func update() {
        busy = true
        DispatchQueue.global().async {
            _ = runCmd("/bin/bash", ["-c", "tmp=$(mktemp -d) && git clone --depth 1 https://github.com/kartikkabadi/login-toggle \"$tmp\" && bash \"$tmp/install.sh\"; rm -rf \"$tmp\""])
            DispatchQueue.main.async { self.busy = false }
        }
    }

    func turnOff() {
        busy = true
        DispatchQueue.global().async {
            _ = runCmd("/bin/bash", [OFF])
            DispatchQueue.main.async {
                self.refresh()
                self.busy = false
            }
        }
    }

    func restore() {
        busy = true
        DispatchQueue.global().async {
            _ = runCmd("/bin/bash", [ON])
            DispatchQueue.main.async {
                self.refresh()
                self.busy = false
            }
        }
    }
}

struct RowView: View {
    let row: Row
    @ObservedObject var m: Model

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(row.name).font(.callout)
                if !row.detail.isEmpty {
                    Text(row.detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { row.on },
                set: { _ in m.toggle(row) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()
            .disabled(m.busy || (!row.on && !row.canEnable))
        }
    }
}

struct ContentView: View {
    @ObservedObject var m: Model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Open at login").font(.headline)
                    if m.loginRows.isEmpty && m.agentRows.isEmpty {
                        Text("Nothing auto-starts. Enjoy the quiet.").foregroundStyle(.secondary)
                    }
                    ForEach(m.loginRows) { row in
                        RowView(row: row, m: m)
                    }
                    if !m.agentRows.isEmpty {
                        Text("Launch agents").font(.headline).padding(.top, 4)
                        ForEach(m.agentRows) { row in
                            RowView(row: row, m: m)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(height: min(CGFloat(m.loginRows.count) * 40 + CGFloat(m.agentRows.count) * 26 + 56, 460))
            Divider()
            HStack {
                Button("Turn all off") { m.turnOff() }
                    .buttonStyle(.borderedProminent)
                    .disabled(m.busy)
                Button("Restore") { m.restore() }
                    .disabled(m.busy)
                Spacer()
                Button("Update") { m.update() }
                    .disabled(m.busy)
                Button("Refresh") { m.refresh() }
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            Text("Switch off = removed from login. State is saved, Restore brings everything back.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 420, alignment: .leading)
        .environment(\.colorScheme, .light)
        .onAppear { m.refresh() }
    }
}

@main
struct LoginToggleApp: App {
    @StateObject var m = Model()
    init() {
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
    }
    var body: some Scene {
        MenuBarExtra("LoginToggle", systemImage: "power") {
            ContentView(m: m)
        }
        .menuBarExtraStyle(.window)
    }
}
