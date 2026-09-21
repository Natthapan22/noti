//
//  AgentAdapter.swift
//  boringNotch
//

import Combine
import Foundation

/// Seam for AI coding agent integrations. UI talks only to `AgentManager`.
@MainActor
protocol AgentAdapter: AnyObject {
    var kind: AgentKind { get }
    var capabilities: AgentCapabilities { get }
    var isAvailable: Bool { get }
    var availabilityMessage: String? { get }
    var sessionsPublisher: AnyPublisher<[AgentSession], Never> { get }

    func startObserving() async
    func stopObserving() async
    func refresh() async

    func respondToPermission(sessionID: UUID, requestID: UUID, allow: Bool) async -> AgentActionResult
    func answerQuestion(sessionID: UUID, questionID: UUID, optionID: UUID) async -> AgentActionResult
    func reviewPlan(sessionID: UUID, planID: UUID, decision: AgentPlanDecision, feedback: String?) async -> AgentActionResult
    func stopSession(sessionID: UUID) async -> AgentActionResult
    func restartSession(sessionID: UUID) async -> AgentActionResult
    func openSession(sessionID: UUID) async -> AgentActionResult
    func focusSession(sessionID: UUID) async -> AgentActionResult
}

extension AgentAdapter {
    func respondToPermission(sessionID: UUID, requestID: UUID, allow: Bool) async -> AgentActionResult {
        .unsupported(reason: "\(kind.displayName) cannot receive permission responses from Boring Notch")
    }

    func answerQuestion(sessionID: UUID, questionID: UUID, optionID: UUID) async -> AgentActionResult {
        .unsupported(reason: "\(kind.displayName) cannot receive answers from Boring Notch")
    }

    func reviewPlan(sessionID: UUID, planID: UUID, decision: AgentPlanDecision, feedback: String?) async -> AgentActionResult {
        .unsupported(reason: "\(kind.displayName) cannot receive plan decisions from Boring Notch")
    }

    func stopSession(sessionID: UUID) async -> AgentActionResult {
        .unsupported(reason: "Stop is not supported for \(kind.displayName)")
    }

    func restartSession(sessionID: UUID) async -> AgentActionResult {
        .unsupported(reason: "Restart is not supported for \(kind.displayName)")
    }
}
