//
//  ProcessDetection.swift
//  boringNotch
//
//  Local-only detection helpers. Never reads credentials or secrets.
//

import AppKit
import Foundation

enum ProcessDetection {
    static func isAppRunning(bundleIdentifiers: [String]) -> Bool {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        return bundleIdentifiers.contains { running.contains($0) }
    }

    /// Match by localized app name (useful when bundle IDs change across Cursor builds).
    static func isAppRunning(named names: [String]) -> Bool {
        let lowered = Set(names.map { $0.lowercased() })
        return NSWorkspace.shared.runningApplications.contains { app in
            guard let name = app.localizedName?.lowercased() else { return false }
            return lowered.contains(name)
        }
    }

    static func runningApp(bundleIdentifiers: [String]) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { app in
            guard let id = app.bundleIdentifier else { return false }
            return bundleIdentifiers.contains(id)
        }
    }

    static func runningApp(named names: [String]) -> NSRunningApplication? {
        let lowered = Set(names.map { $0.lowercased() })
        return NSWorkspace.shared.runningApplications.first { app in
            guard let name = app.localizedName?.lowercased() else { return false }
            return lowered.contains(name)
        }
    }

    /// Exact executable-name check against the cached `ps` snapshot (no extra `pgrep`).
    static func isProcessRunning(exactNames: [String]) -> Bool {
        let safe = exactNames.filter {
            $0.range(of: #"^[A-Za-z0-9._+-]+$"#, options: .regularExpression) != nil
        }
        guard !safe.isEmpty else { return false }
        ensureCommandLineCache()
        cacheLock.lock()
        let snapshot = commandLineCache
        cacheLock.unlock()
        let wanted = Set(safe)
        for line in snapshot {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let token = trimmed.split(separator: " ", maxSplits: 1).first else { continue }
            let base = URL(fileURLWithPath: String(token)).lastPathComponent
            if wanted.contains(base) { return true }
        }
        return false
    }

    // MARK: - Terminal / CLI command-line scan (cached)

    private static let cacheLock = NSLock()
    private static var commandLineCache: [String] = []
    private static var commandLineCacheDate: Date?
    /// Longer than one adapter poll (2.5s) so a whole wave shares a single `ps`.
    private static let commandLineCacheTTL: TimeInterval = 4.0

    /// Refresh `ps` snapshot used by terminal-agent detection.
    static func refreshCommandLineCache() {
        let lines = fetchCommandLines()
        cacheLock.lock()
        commandLineCache = lines
        commandLineCacheDate = Date()
        cacheLock.unlock()
    }

    /// Hold the lock across the fetch so concurrent adapters share one `ps`.
    private static func ensureCommandLineCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let date = commandLineCacheDate, Date().timeIntervalSince(date) < commandLineCacheTTL {
            return
        }
        commandLineCache = fetchCommandLines()
        commandLineCacheDate = Date()
    }

    private static func fetchCommandLines() -> [String] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        // Full command only — smaller than pid+command, enough for needle match.
        proc.arguments = ["-ax", "-o", "command="]
        let out = Pipe()
        let err = Pipe()
        proc.standardOutput = out
        proc.standardError = err
        do {
            try proc.run()
        } catch {
            return []
        }
        // CRITICAL: read before waitUntilExit. Waiting first deadlocks when `ps`
        // output exceeds the pipe buffer (main thread freeze → notch never opens).
        let data = out.fileHandleForReading.readDataToEndOfFile()
        _ = err.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return text.split(whereSeparator: \.isNewline).map(String.init)
    }

    /// True if any running process command line contains one of the allowlisted needles.
    static func commandLineContainsAny(of needles: [String]) -> Bool {
        let safe = needles.filter { !$0.isEmpty && $0.count >= 4 }
        guard !safe.isEmpty else { return false }
        ensureCommandLineCache()
        cacheLock.lock()
        let snapshot = commandLineCache
        cacheLock.unlock()
        for line in snapshot {
            for needle in safe where line.contains(needle) {
                return true
            }
        }
        return false
    }

    /// First matching command line for display (truncated).
    static func firstMatchingCommandLine(of needles: [String], limit: Int = 120) -> String? {
        let safe = needles.filter { !$0.isEmpty && $0.count >= 4 }
        guard !safe.isEmpty else { return nil }
        ensureCommandLineCache()
        cacheLock.lock()
        let snapshot = commandLineCache
        cacheLock.unlock()
        for line in snapshot {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            for needle in safe where trimmed.contains(needle) {
                if trimmed.count <= limit { return trimmed }
                return String(trimmed.prefix(limit)) + "…"
            }
        }
        return nil
    }

    static func which(_ executable: String) -> URL? {
        let paths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            NSHomeDirectory() + "/.local/bin",
            NSHomeDirectory() + "/.cargo/bin",
            NSHomeDirectory() + "/bin"
        ]
        let fileManager = FileManager.default
        for dir in paths {
            let url = URL(fileURLWithPath: dir).appendingPathComponent(executable)
            if fileManager.isExecutableFile(atPath: url.path) {
                return url
            }
        }
        // PATH lookup without executing arbitrary shell from user input
        guard let pathEnv = ProcessInfo.processInfo.environment["PATH"] else { return nil }
        for dir in pathEnv.split(separator: ":") {
            let url = URL(fileURLWithPath: String(dir)).appendingPathComponent(executable)
            if fileManager.isExecutableFile(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    static func directoryExists(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    static func listProjectishFolders(in base: URL, limit: Int = 8) -> [AgentWorkspace] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: base,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .prefix(limit)
            .compactMap { url -> AgentWorkspace? in
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return nil }
                return AgentWorkspace(projectName: url.lastPathComponent, path: url.path)
            }
    }
}

enum KnownAgentApps {
    static let cursorBundleIDs = [
        "com.todesktop.230313mzl4w4u",
        "com.todesktop.230313mzl4w4u92", // current Cursor builds
        "com.cursor.Cursor"
    ]
    static let cursorAppNames = ["Cursor"]
    /// Terminal / CLI signatures (substrings in `ps` command lines).
    static let cursorCommandNeedles = [
        "cursor-agent/",
        "/.local/share/cursor-agent/",
        "/.local/bin/agent --",
        "cursor agent"
    ]
    static let claudeCommandNeedles = [
        "/bin/claude",
        "/.local/bin/claude",
        "@anthropic-ai/claude"
    ]
    static let codexCommandNeedles = [
        "/bin/codex",
        "/.local/bin/codex",
        "@openai/codex"
    ]
    static let geminiCommandNeedles = [
        "/bin/gemini",
        "/.local/bin/gemini",
        "@google/gemini-cli",
        "gemini-cli"
    ]
    static let openCodeCommandNeedles = [
        "/bin/opencode",
        "/.local/bin/opencode"
    ]
    static let qwenCommandNeedles = [
        "/bin/qwen",
        "/.local/bin/qwen"
    ]
    static let kimiCommandNeedles = [
        "/bin/kimi",
        "/.kimi-code/bin/kimi",
        "/.local/bin/kimi"
    ]
    static let vscodeBundleIDs = [
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders"
    ]
    static let terminalBundleIDs = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "dev.warp.Warp-Stable",
        "dev.warp.Warp"
    ]
}
