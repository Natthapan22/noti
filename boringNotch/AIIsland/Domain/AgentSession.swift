//
//  AgentSession.swift
//  boringNotch
//

import Foundation

struct AgentSession: Identifiable, Codable, Hashable {
    var id: UUID
    var agent: AgentKind
    var sessionName: String
    var status: AgentStatus
    var workspace: AgentWorkspace
    var currentTask: String?
    var progress: Double?
    var files: [String]
    var permissionRequest: AgentPermissionRequest?
    var question: AgentQuestion?
    var plan: AgentPlan?
    var usage: AgentUsage?
    var lastError: String?
    var updatedAt: Date
    var focusTarget: AgentFocusTarget?

    init(
        id: UUID = UUID(),
        agent: AgentKind,
        sessionName: String,
        status: AgentStatus = .idle,
        workspace: AgentWorkspace,
        currentTask: String? = nil,
        progress: Double? = nil,
        files: [String] = [],
        permissionRequest: AgentPermissionRequest? = nil,
        question: AgentQuestion? = nil,
        plan: AgentPlan? = nil,
        usage: AgentUsage? = nil,
        lastError: String? = nil,
        updatedAt: Date = Date(),
        focusTarget: AgentFocusTarget? = nil
    ) {
        self.id = id
        self.agent = agent
        self.sessionName = sessionName
        self.status = status
        self.workspace = workspace
        self.currentTask = currentTask
        self.progress = progress
        self.files = files
        self.permissionRequest = permissionRequest
        self.question = question
        self.plan = plan
        self.usage = usage
        self.lastError = lastError
        self.updatedAt = updatedAt
        self.focusTarget = focusTarget
    }

    var needsAttention: Bool { status.needsAttention }

    var summaryLine: String {
        currentTask ?? workspace.projectName
    }
}

struct AgentFocusTarget: Codable, Hashable {
    var applicationBundleID: String?
    var applicationName: String?
    var workspacePath: String?
    var terminalPreferred: Bool
}
