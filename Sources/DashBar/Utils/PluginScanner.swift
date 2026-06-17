import AppKit
import Foundation

final class PluginScanner {

    static let defaultPluginDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("DashBar/plugins")

    /// Persistent enabled/disabled state per plugin name
    static var stateStore: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("DashBar/.plugin-states.json")
    }

    let pluginDir: URL

    init(pluginDir: URL = PluginScanner.defaultPluginDir) {
        self.pluginDir = pluginDir
    }

    func scan() -> [ScriptDescriptor] {
        let fm = FileManager.default
        try? fm.createDirectory(at: pluginDir, withIntermediateDirectories: true)

        let savedStates = Self.loadStateStore()

        guard let entries = try? fm.contentsOfDirectory(
            at: pluginDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var results: [ScriptDescriptor] = []

        for entry in entries {
            if let desc = tryScanFolder(at: entry, savedStates: savedStates) {
                results.append(desc)
            } else if let desc = tryScanLegacyFile(at: entry) {
                results.append(desc)
            }
        }

        return results.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    // MARK: - State persistence

    private static func loadStateStore() -> [String: Bool] {
        guard let data = try? Data(contentsOf: stateStore),
              let dict = try? JSONDecoder().decode([String: Bool].self, from: data)
        else { return [:] }
        return dict
    }

    static func saveEnabledState(pluginName: String, enabled: Bool) {
        var states = loadStateStore()
        states[pluginName] = enabled
        if let data = try? JSONEncoder().encode(states) {
            try? data.write(to: stateStore)
        }
    }

    // MARK: - Folder-based plugin

    private func tryScanFolder(at url: URL, savedStates: [String: Bool]) -> ScriptDescriptor? {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
              isDir.boolValue
        else { return nil }

        let manifestURL = url.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(PluginManifest.self, from: data)
        else { return nil }

        let scriptURL = url.appendingPathComponent(manifest.script)
        let interval = manifest.interval.flatMap { ScriptRunner.parseIntervalString($0) }

        let htmlPath: String?
        if let htmlFile = manifest.html {
            let htmlURL = url.appendingPathComponent(htmlFile)
            htmlPath = FileManager.default.fileExists(atPath: htmlURL.path) ? htmlURL.path : nil
        } else {
            htmlPath = nil
        }

        let popoverSize: NSSize?
        if let w = manifest.popoverWidth, let h = manifest.popoverHeight {
            popoverSize = NSSize(width: w, height: h)
        } else {
            popoverSize = nil
        }

        let iconPath: String? = manifest.icon
        let interpreter = detectInterpreter(for: scriptURL)

        // Determine enabled state: saved state overrides manifest default
        let manifestEnabled = manifest.enabled ?? true
        let enabled = savedStates[manifest.name] ?? manifestEnabled

        return ScriptDescriptor(
            name: manifest.name,
            path: scriptURL.path,
            interval: interval,
            htmlPath: htmlPath,
            popoverSize: popoverSize,
            interpreter: interpreter,
            sfSymbol: manifest.sfSymbol,
            iconPath: iconPath,
            showText: manifest.showText ?? false,
            pluginDir: url,
            enabled: enabled
        )
    }

    // MARK: - Legacy single-file plugin

    private func tryScanLegacyFile(at url: URL) -> ScriptDescriptor? {
        let ext = url.pathExtension
        guard ["sh", "py", "rb", "js", "pl", "swift"].contains(ext) else { return nil }

        let filename = url.lastPathComponent
        let name = extractName(from: filename)
        let interval = ScriptRunner.parseInterval(from: filename)

        return ScriptDescriptor(
            name: name,
            path: url.path,
            interval: interval,
            interpreter: detectInterpreter(for: url),
            pluginDir: url.deletingLastPathComponent()
        )
    }

    // MARK: - Helpers

    private func extractName(from filename: String) -> String {
        let pattern = #"\.\d+(ms|s|m|h|d)\.(sh|py|rb|js|pl|swift)$"#
        if let range = filename.range(of: pattern, options: .regularExpression) {
            return String(filename[..<range.lowerBound])
        }
        return (filename as NSString).deletingPathExtension
    }

    func detectInterpreter(for scriptURL: URL) -> String {
        guard let handle = try? FileHandle(forReadingFrom: scriptURL) else {
            return fallbackInterpreter(for: scriptURL)
        }
        defer { handle.closeFile() }

        guard let line = String(data: handle.readData(ofLength: 512), encoding: .utf8)?
            .components(separatedBy: .newlines).first,
              line.hasPrefix("#!")
        else {
            return fallbackInterpreter(for: scriptURL)
        }

        let shebang = String(line.dropFirst(2).trimmingCharacters(in: .whitespaces))
        if shebang.hasPrefix("/usr/bin/env ") {
            let rest = String(shebang.dropFirst("/usr/bin/env ".count))
            if let cmdPath = findCommandInPath(rest) {
                return cmdPath
            }
            return "/usr/bin/env \(rest)"
        }
        return shebang
    }

    private func fallbackInterpreter(for scriptURL: URL) -> String {
        switch scriptURL.pathExtension {
        case "sh":   return "/bin/sh"
        case "py":   return "/usr/bin/python3"
        case "rb":   return "/usr/bin/ruby"
        case "js":   return "/usr/bin/env node"
        case "pl":   return "/usr/bin/perl"
        case "swift": return "/usr/bin/env swift"
        default:     return "/bin/sh"
        }
    }

    private func findCommandInPath(_ command: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["which", command]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        guard let _ = try? task.run() else { return nil }
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return path.isEmpty ? nil : path
    }
}
