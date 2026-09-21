//
//  MockAgentAdapter.swift
//  boringNotch
//
//  Demo/testing only — simulates permission, question, plan, and status transitions.
//

import Combine
import Foundation

@MainActor
final class MockAgentAdapter: AgentAdapter {
    let kind: AgentKind = .mock
    var capabilities: AgentCapabilities = .demo
    var isAvailable: Bool = true
    var availabilityMessage: String? = "Demo adapter for UI & tests"

    private let subject = CurrentValueSubject<[AgentSession], Never>([])
    var sessionsPublisher: AnyPublisher<[AgentSession], Never> { subject.eraseToAnyPublisher() }

    private var sessions: [AgentSession] = []
    private var simTask: Task<Void, Never>?

    func startObserving() async {
        if sessions.isEmpty {
            sessions = Self.seedSessions()
            subject.send(sessions)
        }
        startSimulationIfNeeded()
    }

    func stopObserving() async {
        simTask?.cancel()
        simTask = nil
    }

    func refresh() async {
        subject.send(sessions)
    }

    func respondToPermission(sessionID: UUID, requestID: UUID, allow: Bool) async -> AgentActionResult {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return .failed(reason: "Session not found")
        }
        guard sessions[idx].permissionRequest?.id == requestID else {
            return .failed(reason: "Permission request mismatch")
        }
        sessions[idx].permissionRequest = nil
        sessions[idx].status = allow ? .working : .failed
        sessions[idx].currentTask = allow ? "Permission granted — continuing" : "Permission denied"
        sessions[idx].lastError = allow ? nil : "User denied permission"
        sessions[idx].updatedAt = Date()
        subject.send(sessions)
        return .success
    }

    func answerQuestion(sessionID: UUID, questionID: UUID, optionID: UUID) async -> AgentActionResult {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return .failed(reason: "Session not found")
        }
        guard let question = sessions[idx].question, question.id == questionID,
              let option = question.options.first(where: { $0.id == optionID }) else {
            return .failed(reason: "Question/option mismatch")
        }
        sessions[idx].question = nil
        sessions[idx].status = .working
        sessions[idx].currentTask = "Answered: \(option.label)"
        sessions[idx].updatedAt = Date()
        subject.send(sessions)
        return .success
    }

    func reviewPlan(sessionID: UUID, planID: UUID, decision: AgentPlanDecision, feedback: String?) async -> AgentActionResult {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return .failed(reason: "Session not found")
        }
        guard sessions[idx].plan?.id == planID else {
            return .failed(reason: "Plan mismatch")
        }
        sessions[idx].plan = nil
        switch decision {
        case .approve:
            sessions[idx].status = .working
            sessions[idx].currentTask = "Plan approved"
        case .reject:
            sessions[idx].status = .failed
            sessions[idx].currentTask = "Plan rejected"
            sessions[idx].lastError = "User rejected plan"
        case .feedback:
            sessions[idx].status = .waiting
            sessions[idx].currentTask = "Feedback: \(feedback ?? "")"
        }
        sessions[idx].updatedAt = Date()
        subject.send(sessions)
        return .success
    }

    func stopSession(sessionID: UUID) async -> AgentActionResult {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return .failed(reason: "Session not found")
        }
        sessions[idx].status = .idle
        sessions[idx].currentTask = "Stopped"
        sessions[idx].updatedAt = Date()
        subject.send(sessions)
        return .success
    }

    func restartSession(sessionID: UUID) async -> AgentActionResult {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return .failed(reason: "Session not found")
        }
        sessions[idx].status = .starting
        sessions[idx].currentTask = "Restarting…"
        sessions[idx].updatedAt = Date()
        subject.send(sessions)
        try? await Task.sleep(nanoseconds: 400_000_000)
        sessions[idx].status = .working
        sessions[idx].currentTask = "Resumed work"
        sessions[idx].updatedAt = Date()
        subject.send(sessions)
        return .success
    }

    func openSession(sessionID: UUID) async -> AgentActionResult {
        .openedExternally
    }

    func focusSession(sessionID: UUID) async -> AgentActionResult {
        .openedExternally
    }

    /// Force a specific demo scenario (for tests / settings).
    func loadScenario(_ scenario: MockScenario) {
        sessions = scenario.sessions()
        subject.send(sessions)
    }

    private func startSimulationIfNeeded() {
        // Keep static seed; do not auto-spam status changes.
    }

    private static func seedSessions() -> [AgentSession] {
        let frontendID = UUID()
        let backendID = UUID()
        let apiID = UUID()
        return [
            AgentSession(
                id: frontendID,
                agent: .mock,
                sessionName: "Frontend",
                status: .working,
                workspace: AgentWorkspace(projectName: "Demo App", path: NSHomeDirectory() + "/Projects/demo"),
                currentTask: "Implement login",
                progress: 0.45,
                files: ["LoginView.swift", "AuthStore.swift"],
                usage: AgentUsage(provider: "demo", tokensUsed: 12_400, requestsUsed: 18, quotaLimit: 100_000, remaining: 87_600, resetsAt: nil, unavailableReason: nil)
            ),
            AgentSession(
                id: backendID,
                agent: .mock,
                sessionName: "Backend",
                status: .permissionRequired,
                workspace: AgentWorkspace(projectName: "Demo App", path: NSHomeDirectory() + "/Projects/demo"),
                currentTask: "bun prisma migrate dev",
                files: ["schema.prisma"],
                permissionRequest: AgentPermissionRequest(
                    kind: .command,
                    title: "Run command",
                    detail: "bun prisma migrate dev"
                )
            ),
            AgentSession(
                id: apiID,
                agent: .mock,
                sessionName: "API",
                status: .completed,
                workspace: AgentWorkspace(projectName: "Demo API", path: nil),
                currentTask: "Add rate limiting",
                progress: 1.0,
                files: ["rateLimit.ts"]
            )
        ]
    }
}

enum MockScenario {
    case mixed
    case permission
    case question
    case plan
    case failed

    func sessions() -> [AgentSession] {
        switch self {
        case .mixed:
            // Reuse the same shape as default seed without calling actor methods.
            return [
                AgentSession(
                    agent: .mock,
                    sessionName: "Frontend",
                    status: .working,
                    workspace: AgentWorkspace(projectName: "Demo App"),
                    currentTask: "Implement login",
                    progress: 0.45
                ),
                AgentSession(
                    agent: .mock,
                    sessionName: "Backend",
                    status: .permissionRequired,
                    workspace: AgentWorkspace(projectName: "Demo App"),
                    currentTask: "bun prisma migrate dev",
                    permissionRequest: AgentPermissionRequest(
                        kind: .command,
                        title: "Run command",
                        detail: "bun prisma migrate dev"
                    )
                ),
                AgentSession(
                    agent: .mock,
                    sessionName: "API",
                    status: .completed,
                    workspace: AgentWorkspace(projectName: "Demo API"),
                    currentTask: "Add rate limiting",
                    progress: 1.0
                )
            ]
        case .permission:
            return [
                AgentSession(
                    agent: .mock,
                    sessionName: "Backend",
                    status: .permissionRequired,
                    workspace: AgentWorkspace(projectName: "Demo"),
                    currentTask: "rm -rf build",
                    permissionRequest: AgentPermissionRequest(
                        kind: .dangerousAction,
                        title: "Dangerous action",
                        detail: "rm -rf build"
                    )
                )
            ]
        case .question:
            return [
                AgentSession(
                    agent: .mock,
                    sessionName: "Deploy",
                    status: .question,
                    workspace: AgentWorkspace(projectName: "Demo"),
                    currentTask: "Which environment?",
                    question: AgentQuestion(
                        prompt: "Which environment?",
                        options: [
                            AgentQuestionOption(label: "Local"),
                            AgentQuestionOption(label: "Staging"),
                            AgentQuestionOption(label: "Production")
                        ]
                    )
                )
            ]
        case .plan:
            return [
                AgentSession(
                    agent: .mock,
                    sessionName: "Refactor",
                    status: .planReview,
                    workspace: AgentWorkspace(projectName: "Demo"),
                    currentTask: "Review plan",
                    plan: AgentPlan(
                        title: "PLAN",
                        steps: [
                            AgentPlanStep(order: 1, text: "Update API"),
                            AgentPlanStep(order: 2, text: "Modify database"),
                            AgentPlanStep(order: 3, text: "Add tests"),
                            AgentPlanStep(order: 4, text: "Update UI")
                        ]
                    )
                )
            ]
        case .failed:
            return [
                AgentSession(
                    agent: .mock,
                    sessionName: "Tests",
                    status: .failed,
                    workspace: AgentWorkspace(projectName: "Demo"),
                    currentTask: "Run test suite",
                    lastError: "exit code 1"
                )
            ]
        }
    }
}
