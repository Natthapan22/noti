//
//  AppFocusService.swift
//  boringNotch
//
//  Focus Terminal / IDE apps. Uses NSWorkspace + optional AppleEvents.
//  Does not silently enable Accessibility.
//

import AppKit
import Foundation

@MainActor
final class AppFocusService {
    static let shared = AppFocusService()

    private init() {}

    func openApplication(bundleIDs: [String], fallbackName: String?) async -> AgentActionResult {
        for id in bundleIDs {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                do {
                    try await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                    return .openedExternally
                } catch {
                    continue
                }
            }
        }
        if let fallbackName {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: fallbackName) {
                do {
                    try await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                    return .openedExternally
                } catch {
                    return .failed(reason: error.localizedDescription)
                }
            }
            let scriptResult = await appleScriptActivate(applicationName: fallbackName)
            return scriptResult
        }
        return .failed(reason: "Application not found")
    }

    func activateRunning(bundleIDs: [String]) -> Bool {
        if let app = ProcessDetection.runningApp(bundleIdentifiers: bundleIDs) {
            return app.activate(options: [.activateIgnoringOtherApps])
        }
        return false
    }

    func openFolder(_ path: String) -> AgentActionResult {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            return .failed(reason: "Path not found")
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        return .openedExternally
    }

    func focus(target: AgentFocusTarget) async -> AgentActionResult {
        if let path = target.workspacePath, FileManager.default.fileExists(atPath: path) {
            // Prefer opening the IDE if known; Finder is fallback via openFolder only when no app
            if let bundle = target.applicationBundleID {
                _ = activateRunning(bundleIDs: [bundle])
                let opened = await openApplication(bundleIDs: [bundle], fallbackName: target.applicationName)
                if case .openedExternally = opened { return opened }
            }
            return openFolder(path)
        }

        if let bundle = target.applicationBundleID {
            if activateRunning(bundleIDs: [bundle]) {
                return .openedExternally
            }
            return await openApplication(bundleIDs: [bundle], fallbackName: target.applicationName)
        }

        if target.terminalPreferred {
            if activateRunning(bundleIDs: KnownAgentApps.terminalBundleIDs) {
                return .openedExternally
            }
            return await openApplication(
                bundleIDs: KnownAgentApps.terminalBundleIDs,
                fallbackName: "Terminal"
            )
        }

        if let name = target.applicationName {
            return await openApplication(bundleIDs: [], fallbackName: name)
        }

        return .failed(reason: "No focus target")
    }

    /// Best-effort AppleScript activate. Requires Apple Events entitlement for target.
    func appleScriptActivate(applicationName: String) async -> AgentActionResult {
        let escaped = applicationName.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"\(escaped)\" to activate"
        do {
            try await AppleScriptHelper.executeVoid(script)
            return .openedExternally
        } catch {
            return .failed(reason: error.localizedDescription)
        }
    }
}
