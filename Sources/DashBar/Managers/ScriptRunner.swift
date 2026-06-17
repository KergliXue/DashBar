import Foundation

@MainActor
final class ScriptRunner {

    private var timers: [String: Timer] = [:]

    func startAll(descriptors: [ScriptDescriptor]) {
        stopAll()
        for desc in descriptors {
            runAndSchedule(desc)
        }
    }

    func stopAll() {
        for timer in timers.values { timer.invalidate() }
        timers.removeAll()
    }

    private func runAndSchedule(_ descriptor: ScriptDescriptor) {
        Task { await Self.runScript(descriptor: descriptor) }
        guard let interval = descriptor.interval else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { await Self.runScript(descriptor: descriptor) }
        }
        timers[descriptor.path] = timer
    }

    nonisolated
    static func runScript(descriptor: ScriptDescriptor) async {
        let output = execute(path: descriptor.path, interpreter: descriptor.interpreter)
        await MainActor.run {
            NotificationCenter.default.post(
                name: .scriptOutput,
                object: nil,
                userInfo: [
                    "name": descriptor.name,
                    "output": output,
                    "htmlPath": descriptor.htmlPath as Any,
                    "popoverSize": descriptor.popoverSize as Any,
                ]
            )
        }
    }

    nonisolated
    private static func execute(path: String, interpreter: String) -> String {
        let process = Process()
        if interpreter.hasPrefix("/usr/bin/env ") {
            let cmd = String(interpreter.dropFirst("/usr/bin/env ".count))
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [cmd, path]
        } else {
            process.executableURL = URL(fileURLWithPath: interpreter)
            process.arguments = [path]
        }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "[error: \(error.localizedDescription)]"
        }
    }
}

// MARK: - Interval parsing (nonisolated, pure functions)

extension ScriptRunner {

    nonisolated static func parseInterval(from filename: String) -> TimeInterval? {
        let pattern = #"\.(\d+)(ms|s|m|h|d)\.(sh|py|rb|js|pl|swift)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(filename.startIndex..., in: filename)
        guard let match = regex.firstMatch(in: filename, range: range),
              let numberRange = Range(match.range(at: 1), in: filename),
              let unitRange = Range(match.range(at: 2), in: filename),
              let value = Double(filename[numberRange])
        else { return nil }

        return intervalFor(value: value, unit: String(filename[unitRange]))
    }

    nonisolated static func parseIntervalString(_ raw: String) -> TimeInterval? {
        let pattern = #"^(\d+)(ms|s|m|h|d)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(raw.startIndex..., in: raw)
        guard let match = regex.firstMatch(in: raw, range: range),
              let numberRange = Range(match.range(at: 1), in: raw),
              let unitRange = Range(match.range(at: 2), in: raw),
              let value = Double(raw[numberRange])
        else { return nil }

        return intervalFor(value: value, unit: String(raw[unitRange]))
    }

    nonisolated private static func intervalFor(value: Double, unit: String) -> TimeInterval? {
        switch unit {
        case "ms": return value / 1000.0
        case "s":  return value
        case "m":  return value * 60.0
        case "h":  return value * 3600.0
        case "d":  return value * 86400.0
        default:   return nil
        }
    }
}

extension Notification.Name {
    static let scriptOutput = Notification.Name("DashBarScriptOutput")
}
