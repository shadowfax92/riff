import Foundation

public protocol ProcessLogger: Sendable {
    func processStarted(id: String, invocation: ProcessInvocation, at date: Date)
    func processFinished(id: String, result: ProcessResult, startedAt: Date, finishedAt: Date)
    func processFailed(id: String, error: Error, startedAt: Date, finishedAt: Date)
}

/// Writes subprocess lifecycle events to daily JSONL files under `~/.riff/logs`.
/// Stdin content is intentionally omitted so large prompts and private context do not end up in logs.
public final class FileProcessLogger: ProcessLogger, @unchecked Sendable {
    private let directoryURL: URL
    private let retention: TimeInterval
    private let now: @Sendable () -> Date
    private let lock = NSLock()

    public init(
        directoryURL: URL,
        retention: TimeInterval = 24 * 60 * 60,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.directoryURL = directoryURL
        self.retention = retention
        self.now = now
    }

    public func processStarted(id: String, invocation: ProcessInvocation, at date: Date) {
        var entry: [String: Any] = [
            "id": id,
            "event": "start",
            "timestamp": isoString(date),
            "command": invocation.command,
            "arguments": invocation.arguments,
            "stdinBytes": invocation.stdin?.utf8.count ?? 0,
        ]
        if let cwd = invocation.workingDirectory?.path {
            entry["cwd"] = cwd
        }
        if let timeout = invocation.timeout {
            entry["timeout"] = timeout
        }
        write(entry, at: date)
    }

    public func processFinished(id: String, result: ProcessResult, startedAt: Date, finishedAt: Date) {
        write([
            "id": id,
            "event": "finish",
            "timestamp": isoString(finishedAt),
            "durationMs": Int(finishedAt.timeIntervalSince(startedAt) * 1000),
            "exitCode": Int(result.exitCode),
            "stdoutBytes": result.stdout.utf8.count,
            "stderrBytes": result.stderr.utf8.count,
            "stderrPreview": preview(result.stderr),
        ], at: finishedAt)
    }

    public func processFailed(id: String, error: Error, startedAt: Date, finishedAt: Date) {
        write([
            "id": id,
            "event": "error",
            "timestamp": isoString(finishedAt),
            "durationMs": Int(finishedAt.timeIntervalSince(startedAt) * 1000),
            "error": String(describing: error),
        ], at: finishedAt)
    }

    private func write(_ entry: [String: Any], at date: Date) {
        lock.lock()
        defer { lock.unlock() }
        do {
            let fileManager = FileManager.default
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try pruneOldLogs(now: now(), fileManager: fileManager)
            let data = try JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys])
            let fileURL = directoryURL.appending(path: logFilename(for: date))
            if !fileManager.fileExists(atPath: fileURL.path) {
                try Data().write(to: fileURL)
            }
            let handle = try FileHandle(forWritingTo: fileURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.write(contentsOf: Data("\n".utf8))
            try handle.close()
        } catch {
            return
        }
    }

    private func pruneOldLogs(now: Date, fileManager: FileManager) throws {
        let cutoff = now.addingTimeInterval(-retention)
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return
        }
        let files = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )
        for file in files where file.lastPathComponent.hasPrefix("runtime-") && file.pathExtension == "log" {
            let values = try file.resourceValues(forKeys: [.contentModificationDateKey])
            if let modified = values.contentModificationDate, modified < cutoff {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    private func logFilename(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return "runtime-\(formatter.string(from: date)).log"
    }

    private func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func preview(_ text: String) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
    }
}
