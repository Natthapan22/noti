//
//  AgentTypes.swift
//  boringNotch
//
//  AI Island domain types — agent identity, status, capabilities, usage.
//

import Foundation
import Defaults

// MARK: - Kind

enum AgentKind: String, CaseIterable, Identifiable, Codable, Defaults.Serializable, Hashable {
    case cursor
    case claudeCode
    case codex
    case geminiCLI
    case openCode
    case qwen
    case kimi
    case copilotCLI
    case remote

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cursor: return "Cursor"
        case .claudeCode: return "Claude Code"
        case .codex: return "Codex"
        case .geminiCLI: return "Gemini CLI"
        case .openCode: return "OpenCode"
        case .qwen: return "Qwen"
        case .kimi: return "Kimi"
        case .copilotCLI: return "Copilot CLI"
        case .remote: return "Remote"
        }
    }

    var systemImage: String {
        switch self {
        case .cursor: return "cursorarrow.rays"
        case .claudeCode: return "terminal"
        case .codex: return "chevron.left.forwardslash.chevron.right"
        case .geminiCLI: return "sparkles"
        case .openCode: return "hammer"
        case .qwen: return "text.bubble"
        case .kimi: return "moon.stars"
        case .copilotCLI: return "person.crop.circle.badge.checkmark"
        case .remote: return "network"
        }
    }
}

// MARK: - Status

enum AgentStatus: String, CaseIterable, Codable, Hashable {
    case idle
    case starting
    case working
    case waiting
    case permissionRequired
    case question
    case planReview
    case completed
    case failed
    case disconnected

    var needsAttention: Bool {
        switch self {
        case .permissionRequired, .question, .failed, .planReview:
            return true
        default:
            return false
        }
    }

    /// Lower number = higher priority (spec order).
    var attentionPriority: Int {
        switch self {
        case .permissionRequired: return 1
        case .question: return 2
        case .failed: return 3
        case .planReview: return 4
        case .completed: return 5
        case .working, .starting: return 6
        case .waiting: return 7
        case .idle: return 8
        case .disconnected: return 9
        }
    }

    var label: String {
        switch self {
        case .idle: return "Ready"
        case .starting: return "Starting"
        case .working: return "Working"
        case .waiting: return "Waiting"
        case .permissionRequired: return "Permission"
        case .question: return "Question"
        case .planReview: return "Plan"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .disconnected: return "Offline"
        }
    }

    /// UI signal color: green = working, orange = needs approval, red = problem.
    var signalColorName: AgentSignalColor {
        switch self {
        case .working, .starting:
            return .green
        case .permissionRequired, .question, .planReview, .waiting:
            return .orange
        case .failed, .disconnected:
            return .red
        case .completed, .idle:
            return .neutral
        }
    }
}

enum AgentSignalColor: Equatable {
    case green
    case orange
    case red
    case neutral
}

// MARK: - Capabilities

struct AgentCapabilities: Codable, Hashable, Equatable {
    var supportsPermission: Bool = false
    var supportsQuestions: Bool = false
    var supportsPlanReview: Bool = false
    var supportsUsage: Bool = false
    var supportsSessionControl: Bool = false
    var supportsTerminalFocus: Bool = false
    var supportsRemoteSession: Bool = false
    var supportsStop: Bool = false
    var supportsRestart: Bool = false
    var supportsOpenApp: Bool = true

    static let openOnly = AgentCapabilities()
}

// MARK: - Permission / Question / Plan

enum AgentPermissionKind: String, Codable, Hashable {
    case command
    case fileAccess
    case toolCall
    case dangerousAction
    case networkAction
}

struct AgentPermissionRequest: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var kind: AgentPermissionKind
    var title: String
    var detail: String
    var createdAt: Date = Date()
}

struct AgentQuestionOption: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var label: String
}

struct AgentQuestion: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var prompt: String
    var options: [AgentQuestionOption]
    var createdAt: Date = Date()
}

struct AgentPlanStep: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var order: Int
    var text: String
}

struct AgentPlan: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var steps: [AgentPlanStep]
    var createdAt: Date = Date()
}

enum AgentPlanDecision: String, Codable {
    case approve
    case reject
    case feedback
}

// MARK: - Usage

struct AgentUsage: Codable, Hashable, Equatable {
    var provider: String
    var tokensUsed: Int?
    var requestsUsed: Int?
    var quotaLimit: Int?
    var remaining: Int?
    var resetsAt: Date?
    var unavailableReason: String?

    static func unavailable(_ reason: String = "Usage unavailable") -> AgentUsage {
        AgentUsage(
            provider: "unknown",
            tokensUsed: nil,
            requestsUsed: nil,
            quotaLimit: nil,
            remaining: nil,
            resetsAt: nil,
            unavailableReason: reason
        )
    }
}

// MARK: - Workspace

struct AgentWorkspace: Codable, Hashable, Equatable {
    var projectName: String
    var path: String?
    var remoteHost: String?

    var displayPath: String {
        path ?? remoteHost ?? projectName
    }
}

// MARK: - Action result

enum AgentActionResult: Equatable {
    case success
    case unsupported(reason: String)
    case failed(reason: String)
    case openedExternally
}

// MARK: - Filter

enum AgentSessionFilter: String, CaseIterable, Identifiable {
    case all
    case working
    case needsAttention
    case completed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .working: return "Working"
        case .needsAttention: return "Attention"
        case .completed: return "Completed"
        }
    }
}
