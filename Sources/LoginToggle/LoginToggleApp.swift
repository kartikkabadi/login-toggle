import SwiftUI
import Darwin

private let HOME = FileManager.default.homeDirectoryForCurrentUser.path
private let OFF = HOME + "/.local/bin/login-off"
private let ON = HOME + "/.local/bin/login-on"

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

final class Model: ObservableObject {
    @Published var loginItems: [String] = []
    @Published var agents: [(String, Bool)] = []
    @Published var busy = false

    func refresh() {
        var items: [String] = []
        let raw = runCmd("/usr/bin/osascript", ["-e", "tell application \"System Events\" to get name of every login item"])
        for n in raw.split(separator: ",") {
            let s = n.trimmingCharacters(in: .whitespaces)
            if !s.isEmpty { items.append(s) }
        }
        loginItems = items

        var list: [(String, Bool)] = []
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
                list.append((label, off))
            }
        }
        agents = list
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

struct ContentView: View {
    @ObservedObject var m: Model

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Open at login").font(.headline)
            if m.loginItems.isEmpty && m.agents.isEmpty {
                Text("Nothing auto-starts. Enjoy the quiet.").foregroundStyle(.secondary)
            }
            ForEach(m.loginItems, id: \.self) { name in
                Text(name).font(.callout)
            }
            ForEach(m.agents, id: \.0) { a in
                HStack {
                    Text(a.0).font(.callout)
                    Spacer()
                    Text(a.1 ? "off" : "on")
                        .font(.caption)
                        .foregroundStyle(a.1 ? Color.secondary : Color.primary)
                }
            }
            Divider()
            HStack {
                Button("Turn all off") { m.turnOff() }
                    .buttonStyle(.borderedProminent)
                    .disabled(m.busy)
                Button("Restore") { m.restore() }
                    .disabled(m.busy)
                Spacer()
                Button("Refresh") { m.refresh() }
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            Text("Launch agents return at next login. Background items (SMAppService) live in System Settings.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 380, alignment: .leading)
        .onAppear { m.refresh() }
    }
}

@main
struct LoginToggleApp: App {
    @StateObject var m = Model()
    var body: some Scene {
        MenuBarExtra("LoginToggle", systemImage: "power.dotted") {
            ContentView(m: m)
        }
        .menuBarExtraStyle(.window)
    }
}
