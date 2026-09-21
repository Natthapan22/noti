//
//  CursorAdapter.swift
//  boringNotch
//
//  Detects Cursor via running app / support folder. Does not invent agent RPC.
//

import Foundation

@MainActor
final class CursorAdapter: DetectingAgentAdapter {
    init() {
        let support = NSHomeDirectory() + "/Library/Application Support/Cursor"
        super.init(
            kind: .cursor,
            bundleIDs: KnownAgentApps.cursorBundleIDs,
            cliNames: ["cursor"],
            supportPaths: [support],
            appDisplayName: "Cursor"
        )
    }

    override func buildSessions(running: Bool, cliPresent: Bool) -> [AgentSession] {
        guard isAvailable else { return [] }

        let storageBase = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support/Cursor/User/workspaceStorage")
        let workspaces = ProcessDetection.listProjectishFolders(in: storageBase, limit: 5)

        if workspaces.isEmpty {
            return [
                AgentSession(
                    agent: .cursor,
                    sessionName: "Cursor",
                    status: running ? .idle : .disconnected,
                    workspace: AgentWorkspace(projectName: "Cursor"),
                    currentTask: availabilityMessage,
                    focusTarget: AgentFocusTarget(
                        applicationBundleID: KnownAgentApps.cursorBundleIDs.first,
                        applicationName: "Cursor",
                        workspacePath: nil,
                        terminalPreferred: false
                    )
                )
            ]
        }

        return workspaces.prefix(3).enumerated().map { index, ws in
            AgentSession(
                agent: .cursor,
                sessionName: ws.projectName,
                status: running ? .idle : .disconnected,
                workspace: ws,
                currentTask: running
                    ? "Open in Cursor (live agent status unavailable)"
                    : "Cursor not running",
                focusTarget: AgentFocusTarget(
                    applicationBundleID: KnownAgentApps.cursorBundleIDs.first,
                    applicationName: "Cursor",
                    workspacePath: ws.path,
                    terminalPreferred: false
                )
            )
        }
    }
}

@MainActor
final class ClaudeCodeAdapter: DetectingAgentAdapter {
    init() {
        let home = NSHomeDirectory()
        super.init(
            kind: .claudeCode,
            bundleIDs: [],
            cliNames: ["claude"],
            supportPaths: [
                home + "/.claude",
                home + "/.config/claude"
            ],
            appDisplayName: "Claude Code",
            baseCapabilities: AgentCapabilities(
                supportsPermission: false,
                supportsQuestions: false,
                supportsPlanReview: false,
                supportsUsage: false,
                supportsSessionControl: false,
                supportsTerminalFocus: true,
                supportsRemoteSession: false,
                supportsStop: false,
                supportsRestart: false,
                supportsOpenApp: true
            )
        )
    }

    override func buildSessions(running: Bool, cliPresent: Bool) -> [AgentSession] {
        guard isAvailable else { return [] }
        return [
            AgentSession(
                agent: .claudeCode,
                sessionName: "CLI",
                status: cliPresent ? .idle : .disconnected,
                workspace: AgentWorkspace(projectName: "Claude Code"),
                currentTask: "No live session bridge — use Open Terminal",
                focusTarget: AgentFocusTarget(
                    applicationBundleID: KnownAgentApps.terminalBundleIDs.first,
                    applicationName: "Terminal",
                    workspacePath: nil,
                    terminalPreferred: true
                )
            )
        ]
    }
}

@MainActor
final class CodexAdapter: DetectingAgentAdapter {
    init() {
        super.init(
            kind: .codex,
            cliNames: ["codex"],
            supportPaths: [NSHomeDirectory() + "/.codex"],
            appDisplayName: "Codex"
        )
    }
}

@MainActor
final class GeminiCLIAdapter: DetectingAgentAdapter {
    init() {
        super.init(
            kind: .geminiCLI,
            cliNames: ["gemini"],
            supportPaths: [NSHomeDirectory() + "/.gemini"],
            appDisplayName: "Gemini CLI"
        )
    }
}

@MainActor
final class OpenCodeAdapter: DetectingAgentAdapter {
    init() {
        super.init(
            kind: .openCode,
            cliNames: ["opencode"],
            supportPaths: [
                NSHomeDirectory() + "/.opencode",
                NSHomeDirectory() + "/.config/opencode"
            ],
            appDisplayName: "OpenCode"
        )
    }
}

@MainActor
final class QwenAdapter: DetectingAgentAdapter {
    init() {
        super.init(
            kind: .qwen,
            cliNames: ["qwen"],
            supportPaths: [NSHomeDirectory() + "/.qwen"],
            appDisplayName: "Qwen"
        )
    }
}

@MainActor
final class KimiAdapter: DetectingAgentAdapter {
    init() {
        super.init(
            kind: .kimi,
            cliNames: ["kimi"],
            supportPaths: [NSHomeDirectory() + "/.kimi"],
            appDisplayName: "Kimi"
        )
    }
}

@MainActor
final class CopilotCLIAdapter: DetectingAgentAdapter {
    init() {
        super.init(
            kind: .copilotCLI,
            cliNames: ["gh", "copilot"],
            supportPaths: [],
            appDisplayName: "GitHub Copilot CLI"
        )
    }

    override func buildSessions(running: Bool, cliPresent: Bool) -> [AgentSession] {
        // Only report available if `gh` exists; do not claim Copilot without evidence.
        let hasGH = ProcessDetection.which("gh") != nil
        updateAvailability(
            hasGH,
            message: hasGH
                ? "GitHub CLI found — Copilot session bridge not available"
                : "GitHub CLI not detected"
        )
        guard hasGH else { return [] }
        return [
            AgentSession(
                agent: .copilotCLI,
                sessionName: "Copilot",
                status: .disconnected,
                workspace: AgentWorkspace(projectName: "GitHub Copilot"),
                currentTask: availabilityMessage,
                focusTarget: AgentFocusTarget(
                    applicationBundleID: nil,
                    applicationName: "Terminal",
                    workspacePath: nil,
                    terminalPreferred: true
                )
            )
        ]
    }
}

/// Architecture placeholder for SSH / remote agent sessions.
@MainActor
final class RemoteAgentAdapter: DetectingAgentAdapter {
    init() {
        var caps = AgentCapabilities.openOnly
        caps.supportsRemoteSession = true
        super.init(
            kind: .remote,
            bundleIDs: [],
            cliNames: ["ssh"],
            supportPaths: [],
            appDisplayName: "Remote SSH",
            baseCapabilities: caps
        )
    }

    override func buildSessions(running: Bool, cliPresent: Bool) -> [AgentSession] {
        // Honest stub: architecture only until remote monitoring is implemented.
        guard ProcessDetection.which("ssh") != nil else {
            updateAvailability(false, message: "ssh not found")
            return []
        }
        updateAvailability(true, message: "Remote monitoring not implemented yet")
        return [
            AgentSession(
                agent: .remote,
                sessionName: "SSH",
                status: .disconnected,
                workspace: AgentWorkspace(projectName: "Remote", remoteHost: nil),
                currentTask: "RemoteAgentAdapter ready — no active tunnels monitored",
                focusTarget: AgentFocusTarget(terminalPreferred: true)
            )
        ]
    }
}
