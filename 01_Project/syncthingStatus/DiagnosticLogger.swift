import Foundation
import OSLog

/// Exports unified-log entries for the app's subsystem to a plain-text file
/// users can attach to bug reports.
///
/// Uses `OSLogStore(scope: .currentProcessIdentifier)` so it works inside the
/// App Sandbox without `com.apple.developer.logging` (which App Store apps
/// can't ship with). The trade-off: only the *current* process's entries are
/// captured. Users hitting a bug should reproduce it before exporting.
///
/// Output lands at `~/Library/Application Support/syncthingStatus/diagnostic.log`
/// — which, for the sandboxed build, resolves inside the app's container.
enum DiagnosticLogger {
    static let subsystem = "com.lucesumbrarum.syncthingStatus"
    private static let log = Logger(subsystem: subsystem, category: "Diagnostics")

    enum ExportError: Error, LocalizedError {
        case storeUnavailable(Error)
        case enumerationFailed(Error)
        case writeFailed(Error)

        var errorDescription: String? {
            switch self {
            case .storeUnavailable(let e): return "Couldn't open the system log: \(e.localizedDescription)"
            case .enumerationFailed(let e): return "Couldn't read log entries: \(e.localizedDescription)"
            case .writeFailed(let e): return "Couldn't write the log file: \(e.localizedDescription)"
            }
        }
    }

    /// Reads recent unified-log entries and writes them to the diagnostic log
    /// file. Returns the file URL on success.
    static func export() throws -> URL {
        log.notice("Diagnostic export requested")

        let store: OSLogStore
        do {
            store = try OSLogStore(scope: .currentProcessIdentifier)
        } catch {
            throw ExportError.storeUnavailable(error)
        }

        let position = store.position(timeIntervalSinceLatestBoot: 0)
        let predicate = NSPredicate(format: "subsystem == %@", subsystem)

        let entries: AnySequence<OSLogEntry>
        do {
            entries = try store.getEntries(at: position, matching: predicate)
        } catch {
            throw ExportError.enumerationFailed(error)
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var output = "syncthingStatus diagnostic log\n"
        output += "Exported: \(formatter.string(from: Date()))\n"
        output += "App version: \(Self.appVersionString())\n"
        output += "Subsystem: \(subsystem)\n"
        output += "Scope: current process (entries since launch)\n"
        output += String(repeating: "-", count: 64) + "\n"

        var entryCount = 0
        for entry in entries {
            guard let entryLog = entry as? OSLogEntryLog else { continue }
            let ts = formatter.string(from: entryLog.date)
            output += "[\(ts)] [\(entryLog.category)] [\(levelString(entryLog.level))] \(entryLog.composedMessage)\n"
            entryCount += 1
        }

        if entryCount == 0 {
            output += "(no entries yet — reproduce the issue, then export again)\n"
        }

        let url = try logFileURL()
        do {
            try output.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw ExportError.writeFailed(error)
        }
        return url
    }

    private static func logFileURL() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = appSupport.appendingPathComponent("syncthingStatus", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("diagnostic.log")
    }

    private static func levelString(_ level: OSLogEntryLog.Level) -> String {
        switch level {
        case .undefined: return "undef"
        case .debug:     return "debug"
        case .info:      return "info"
        case .notice:    return "notice"
        case .error:     return "error"
        case .fault:     return "fault"
        @unknown default: return "?"
        }
    }

    private static func appVersionString() -> String {
        let info = Bundle.main.infoDictionary
        let marketing = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(marketing) (\(build))"
    }
}
