//
//  ConcreteAdapters.swift
//  boringNotch
//
//  Detects agents via running app / CLI / terminal command lines.
//

import Foundation

@MainActor
final class CursorAdapter: DetectingAgentAdapter {
    init() {
        let support = NSHomeDirectory() + "/Library/Application Support/Cursor"
        super.init(
            kind: .cursor,
            bundleIDs: KnownAgentApps.cursorBundleIDs,
            appNames: KnownAgentApps.cursorAppNames,
            cliNames: ["cursor", "agent"],
            commandLineNeedles: KnownAgentApps.cursorCommandNeedles,
            supportPaths: [support],
            appDisplayName: "Cursor"
        )
    }

    override func buildSessions(appRunning: Bool, cliProcessRunning: Bool, cliPresent: Bool) -> [AgentSession] {
        guard isAvailable else { return [] }

        let storageBase = URL(
            fileURLWithPath: NSHomeDirectory() + "/Library/Application Support/Cursor/User/workspaceStorage"
        )
        let workspace = ProcessDetection.listProjectishFolders(in: storageBase, limit: 1).first
            ?? AgentWorkspace(projectName: "Cursor")

        let task: String
        let status: AgentStatus
        if cliProcessRunning {
            status = .working
            task = availabilityMessage ?? "cursor-agent running"
        } else if appRunning {
            status = .idle
            task = "Ready"
        } else {
            status = .idle
            task = workspace.path == nil
                ? (availabilityMessage ?? "Ready")
                : "Ready — recent workspace available"
        }

        let focus = AgentFocusTarget(
            applicationBundleID: cliProcessRunning && !appRunning
                ? KnownAgentApps.terminalBundleIDs.first
                : KnownAgentApps.cursorBundleIDs.first,
            applicationName: cliProcessRunning && !appRunning ? "Terminal" : "Cursor",
            workspacePath: workspace.path,
            terminalPreferred: cliProcessRunning && !appRunning
        )

        return [
            AgentSession(
                agent: .cursor,
                sessionName: "Cursor",
                status: status,
                workspace: workspace,
                currentTask: task,
                focusTarget: focus
            )
        ]
    }
}

@MainActor
final class ClaudeCodeAdapter: DetectingAgentAdapter {
    init() {
        let home = NSHomeDirectory()
        super.init(
            kind: .claudeCode,
            cliNames: ["claude"],
            processNames: ["claude"],
            commandLineNeedles: KnownAgentApps.claudeCommandNeedles,
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
}

@MainActor
final class CodexAdapter: DetectingAgentAdapter {
    init() {
        super.init(
            kind: .codex,
            cliNames: ["codex"],
            processNames: ["codex"],
            commandLineNeedles: KnownAgentApps.codexCommandNeedles,
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
            processNames: ["gemini"],
            commandLineNeedles: KnownAgentApps.geminiCommandNeedles,
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
            processNames: ["opencode"],
            commandLineNeedles: KnownAgentApps.openCodeCommandNeedles,
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
            processNames: ["qwen"],
            commandLineNeedles: KnownAgentApps.qwenCommandNeedles,
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
            processNames: ["kimi"],
            commandLineNeedles: KnownAgentApps.kimiCommandNeedles,
            supportPaths: [
                NSHomeDirectory() + "/.kimi",
                NSHomeDirectory() + "/.kimi-code"
            ],
            appDisplayName: "Kimi"
        )
    }
}

@MainActor
final class CopilotCLIAdapter: DetectingAgentAdapter {
    init() {
        super.init(
            kind: .copilotCLI,
            cliNames: ["gh"],
            commandLineNeedles: ["gh copilot", "gh-copilot"],
            supportPaths: [],
            appDisplayName: "GitHub Copilot CLI"
        )
    }

    override func buildSessions(appRunning: Bool, cliProcessRunning: Bool, cliPresent: Bool) -> [AgentSession] {
        let hasGH = ProcessDetection.which("gh") != nil
        updateAvailability(hasGH || cliProcessRunning, message: availabilityMessage)
        guard hasGH || cliProcessRunning else { return [] }
        return [
            AgentSession(
                agent: .copilotCLI,
                sessionName: "Copilot",
                status: cliProcessRunning ? .working : .idle,
                workspace: AgentWorkspace(projectName: "GitHub Copilot"),
                currentTask: availabilityMessage,
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
final class RemoteAgentAdapter: DetectingAgentAdapter {
    init() {
        var caps = AgentCapabilities.openOnly
        caps.supportsRemoteSession = true
        super.init(
            kind: .remote,
            cliNames: ["ssh"],
            processNames: ["ssh"],
            commandLineNeedles: [" ssh ", "/usr/bin/ssh"],
            supportPaths: [],
            appDisplayName: "Remote SSH",
            baseCapabilities: caps
        )
    }

    override func buildSessions(appRunning: Bool, cliProcessRunning: Bool, cliPresent: Bool) -> [AgentSession] {
        guard ProcessDetection.which("ssh") != nil || cliProcessRunning else {
            updateAvailability(false, message: "ssh not found")
            return []
        }
        updateAvailability(true, message: availabilityMessage)
        return [
            AgentSession(
                agent: .remote,
                sessionName: "SSH",
                status: cliProcessRunning ? .working : .idle,
                workspace: AgentWorkspace(projectName: "Remote", remoteHost: nil),
                currentTask: availabilityMessage,
                focusTarget: AgentFocusTarget(terminalPreferred: true)
            )
        ]
    }
}
