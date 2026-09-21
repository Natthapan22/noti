//
//  AgentManager.swift
//  boringNotch
//
//  Facade for AI Island — same role as MusicManager for media.
//

import AppKit
import Combine
import Defaults
import Foundation
import SwiftUI

extension Notification.Name {
    static let aiIslandAttentionChanged = Notification.Name("aiIslandAttentionChanged")
    static let aiIslandDemoModeChanged = Notification.Name("aiIslandDemoModeChanged")
}

@MainActor
final class AgentManager: ObservableObject {
    static let shared = AgentManager()

    @Published private(set) var sessions: [AgentSession] = []
    @Published private(set) var attention: AgentAttentionSummary = .init(
        workingCount: 0,
        attentionCount: 0,
        completedCount: 0,
        totalCount: 0,
        topPrioritySession: nil
    )
    @Published private(set) var selectedSessionID: UUID?
    @Published private(set) var lastEvent: AgentEvent?
    @Published private(set) var adapterStatuses: [AgentKind: String] = [:]
    @Published var filter: AgentSessionFilter = .all
    @Published var projectFilter: String = "All"
    @Published var agentFilter: AgentKind? = nil

    private var adapters: [AgentKind: any AgentAdapter] = [:]
    private var lifecycleCancellables = Set<AnyCancellable>()
    private var adapterCancellables = Set<AnyCancellable>()
    private var sessionsByAgent: [AgentKind: [AgentSession]] = [:]
    private var lastNotifiedAttentionSignature: String = ""
    private var started = false

    private init() {
        registerDefaultAdapters()
        NotificationCenter.default.publisher(for: .aiIslandDemoModeChanged)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.rebuildAdaptersForSettings()
                }
            }
            .store(in: &lifecycleCancellables)
    }

    var selectedSession: AgentSession? {
        guard let id = selectedSessionID else { return nil }
        return sessions.first { $0.id == id }
    }

    var displayedSessions: [AgentSession] {
        var list = AgentAttention.filter(sessions, by: filter)
        if let agentFilter {
            list = list.filter { $0.agent == agentFilter }
        }
        if projectFilter != "All" {
            list = list.filter { $0.workspace.projectName == projectFilter }
        }
        if Defaults[.aiIslandHideIdleAgents] {
            list = list.filter { $0.status != .idle && $0.status != .disconnected }
        }
        return AgentAttention.sortedForDisplay(list)
    }

    var projectNames: [String] {
        let names = Set(sessions.map(\.workspace.projectName))
        return ["All"] + names.sorted()
    }

    func startIfNeeded() {
        guard Defaults[.aiIslandEnabled] else { return }
        guard !started else { return }
        started = true
        Task { await startAll() }
    }

    func stopAll() async {
        for adapter in adapters.values {
            await adapter.stopObserving()
        }
        adapterCancellables.removeAll()
        started = false
    }

    func refreshAll() async {
        await Task.detached(priority: .utility) {
            ProcessDetection.refreshCommandLineCache()
        }.value
        for adapter in adapters.values {
            await adapter.refresh()
        }
        publishMerged()
    }

    func selectSession(_ id: UUID?) {
        selectedSessionID = id
    }

    func capabilities(for kind: AgentKind) -> AgentCapabilities {
        adapters[kind]?.capabilities ?? .openOnly
    }

    func respondToPermission(sessionID: UUID, allow: Bool) async -> AgentActionResult {
        guard let session = sessions.first(where: { $0.id == sessionID }),
              let request = session.permissionRequest,
              let adapter = adapters[session.agent] else {
            return .failed(reason: "Session or permission not found")
        }
        guard adapter.capabilities.supportsPermission else {
            return await adapter.openSession(sessionID: sessionID)
        }
        return await adapter.respondToPermission(
            sessionID: sessionID,
            requestID: request.id,
            allow: allow
        )
    }

    func answerQuestion(sessionID: UUID, optionID: UUID) async -> AgentActionResult {
        guard let session = sessions.first(where: { $0.id == sessionID }),
              let question = session.question,
              let adapter = adapters[session.agent] else {
            return .failed(reason: "Session or question not found")
        }
        guard adapter.capabilities.supportsQuestions else {
            return await adapter.openSession(sessionID: sessionID)
        }
        return await adapter.answerQuestion(
            sessionID: sessionID,
            questionID: question.id,
            optionID: optionID
        )
    }

    func reviewPlan(sessionID: UUID, decision: AgentPlanDecision, feedback: String?) async -> AgentActionResult {
        guard let session = sessions.first(where: { $0.id == sessionID }),
              let plan = session.plan,
              let adapter = adapters[session.agent] else {
            return .failed(reason: "Session or plan not found")
        }
        guard adapter.capabilities.supportsPlanReview else {
            return await adapter.openSession(sessionID: sessionID)
        }
        return await adapter.reviewPlan(
            sessionID: sessionID,
            planID: plan.id,
            decision: decision,
            feedback: feedback
        )
    }

    func openSession(_ sessionID: UUID) async -> AgentActionResult {
        guard let session = sessions.first(where: { $0.id == sessionID }),
              let adapter = adapters[session.agent] else {
            return .failed(reason: "Session not found")
        }
        return await adapter.openSession(sessionID: sessionID)
    }

    func focusSession(_ sessionID: UUID) async -> AgentActionResult {
        guard let session = sessions.first(where: { $0.id == sessionID }),
              let adapter = adapters[session.agent] else {
            return .failed(reason: "Session not found")
        }
        if let target = session.focusTarget {
            let focused = await AppFocusService.shared.focus(target: target)
            if case .openedExternally = focused { return focused }
        }
        return await adapter.focusSession(sessionID: sessionID)
    }

    func stopSession(_ sessionID: UUID) async -> AgentActionResult {
        guard let session = sessions.first(where: { $0.id == sessionID }),
              let adapter = adapters[session.agent] else {
            return .failed(reason: "Session not found")
        }
        guard adapter.capabilities.supportsStop else {
            return .unsupported(reason: "Stop not supported for \(session.agent.displayName)")
        }
        return await adapter.stopSession(sessionID: sessionID)
    }

    func openProject(for sessionID: UUID) -> AgentActionResult {
        guard let session = sessions.first(where: { $0.id == sessionID }),
              let path = session.workspace.path else {
            return .failed(reason: "No project path")
        }
        return AppFocusService.shared.openFolder(path)
    }

    func loadMockScenario(_ scenario: MockScenario) {
        guard let mock = adapters[.mock] as? MockAgentAdapter else { return }
        mock.loadScenario(scenario)
    }

    // MARK: - Private

    private func registerDefaultAdapters() {
        let list: [any AgentAdapter] = [
            CursorAdapter(),
            ClaudeCodeAdapter(),
            CodexAdapter(),
            GeminiCLIAdapter(),
            OpenCodeAdapter(),
            QwenAdapter(),
            KimiAdapter(),
            CopilotCLIAdapter(),
            RemoteAgentAdapter(),
            MockAgentAdapter()
        ]
        for adapter in list {
            adapters[adapter.kind] = adapter
        }
    }

    private func rebuildAdaptersForSettings() async {
        await stopAll()
        sessionsByAgent.removeAll()
        sessions = []
        publishMerged()
        startIfNeeded()
    }

    private func startAll() async {
        adapterCancellables.removeAll()
        let enabled = Set(Defaults[.aiIslandEnabledAgents])
        let demo = Defaults[.aiIslandDemoMode]

        for (kind, adapter) in adapters {
            let shouldRun: Bool = {
                if kind == .mock { return demo }
                return enabled.contains(kind.rawValue)
            }()
            guard shouldRun else {
                sessionsByAgent[kind] = []
                continue
            }
            adapter.sessionsPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] sessions in
                    guard let self else { return }
                    self.sessionsByAgent[kind] = sessions
                    self.adapterStatuses[kind] = adapter.availabilityMessage
                        ?? (adapter.isAvailable ? "OK" : "Unavailable")
                    self.publishMerged()
                }
                .store(in: &adapterCancellables)
            await adapter.startObserving()
        }
        publishMerged()
    }

    private func publishMerged() {
        let enabled = Set(Defaults[.aiIslandEnabledAgents])
        let demo = Defaults[.aiIslandDemoMode]
        var merged: [AgentSession] = []
        for (kind, list) in sessionsByAgent {
            if kind == .mock {
                if demo { merged.append(contentsOf: list) }
            } else if enabled.contains(kind.rawValue) {
                merged.append(contentsOf: list)
            }
        }
        sessions = AgentAttention.sortedForDisplay(merged)
        let previousAttention = attention.attentionCount
        attention = AgentAttention.summarize(sessions)
        maybeNotifyAttentionChange(previousAttentionCount: previousAttention)

        if let selectedSessionID,
           !sessions.contains(where: { $0.id == selectedSessionID }) {
            self.selectedSessionID = nil
        }
    }

    private func maybeNotifyAttentionChange(previousAttentionCount: Int) {
        guard Defaults[.aiIslandNotifications] else { return }
        let signature = sessions
            .filter(\.needsAttention)
            .map { "\($0.id.uuidString):\($0.status.rawValue)" }
            .sorted()
            .joined(separator: "|")
        guard signature != lastNotifiedAttentionSignature else { return }
        if attention.attentionCount > 0 {
            lastNotifiedAttentionSignature = signature
            if let top = attention.topPrioritySession {
                lastEvent = .statusChanged(sessionID: top.id, status: top.status)
            }
            BoringViewCoordinator.shared.toggleSneakPeek(
                status: true,
                type: .agent,
                duration: 1.8,
                value: CGFloat(attention.attentionCount),
                icon: "exclamationmark.triangle.fill"
            )
            NotificationCenter.default.post(name: .aiIslandAttentionChanged, object: nil)
        } else if previousAttentionCount > 0 {
            lastNotifiedAttentionSignature = signature
        }
    }
}
