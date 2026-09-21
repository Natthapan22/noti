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

    static func runningApp(bundleIdentifiers: [String]) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { app in
            guard let id = app.bundleIdentifier else { return false }
            return bundleIdentifiers.contains(id)
        }
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
        "com.cursor.Cursor"
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
