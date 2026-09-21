//
//  DetectingAgentAdapter.swift
//  boringNotch
//
//  Base adapter: detect install/running, expose open/focus, never invent agent RPC state.
//

import Combine
import Foundation

@MainActor
class DetectingAgentAdapter: AgentAdapter {
    let kind: AgentKind
    private(set) var capabilities: AgentCapabilities
    private(set) var isAvailable: Bool = false
    private(set) var availabilityMessage: String? = "Not detected"

    private let subject = CurrentValueSubject<[AgentSession], Never>([])
    var sessionsPublisher: AnyPublisher<[AgentSession], Never> { subject.eraseToAnyPublisher() }

    private let bundleIDs: [String]
    private let cliNames: [String]
    private let supportPaths: [String]
    private let appDisplayName: String
    private var refreshTask: Task<Void, Never>?

    init(
        kind: AgentKind,
        bundleIDs: [String] = [],
        cliNames: [String] = [],
        supportPaths: [String] = [],
        appDisplayName: String,
        baseCapabilities: AgentCapabilities = .openOnly
    ) {
        self.kind = kind
        self.bundleIDs = bundleIDs
        self.cliNames = cliNames
        self.supportPaths = supportPaths
        self.appDisplayName = appDisplayName
        var caps = baseCapabilities
        caps.supportsOpenApp = true
        caps.supportsTerminalFocus = !bundleIDs.isEmpty || !cliNames.isEmpty
        self.capabilities = caps
    }

    func startObserving() async {
        await refresh()
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await self?.refresh()
            }
        }
    }

    func stopObserving() async {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() async {
        let running = !bundleIDs.isEmpty && ProcessDetection.isAppRunning(bundleIdentifiers: bundleIDs)
        let cliURL = cliNames.compactMap { ProcessDetection.which($0) }.first
        let supportHit = supportPaths.contains { ProcessDetection.directoryExists($0) }

        isAvailable = running || cliURL != nil || supportHit

        if running {
            availabilityMessage = "\(appDisplayName) is running"
        } else if cliURL != nil {
            availabilityMessage = "CLI found at \(cliURL!.path)"
        } else if supportHit {
            availabilityMessage = "Local support data found"
        } else {
            availabilityMessage = "\(appDisplayName) not detected — Open/Focus only"
        }

        var caps = capabilities
        caps.supportsOpenApp = true
        caps.supportsTerminalFocus = running || cliURL != nil
        // Explicitly false until proven otherwise — no fake permission/plan bridge
        caps.supportsPermission = false
        caps.supportsQuestions = false
        caps.supportsPlanReview = false
        caps.supportsUsage = false
        caps.supportsSessionControl = false
        caps.supportsStop = false
        caps.supportsRestart = false
        capabilities = caps

        let sessions = buildSessions(running: running, cliPresent: cliURL != nil)
        subject.send(sessions)
    }

    func updateAvailability(_ available: Bool, message: String?) {
        isAvailable = available
        availabilityMessage = message
    }

    /// Subclasses override to attach real workspace evidence when available.
    func buildSessions(running: Bool, cliPresent: Bool) -> [AgentSession] {
        guard isAvailable else { return [] }
        return [
            AgentSession(
                agent: kind,
                sessionName: "Default",
                status: running ? .idle : .disconnected,
                workspace: AgentWorkspace(projectName: appDisplayName, path: nil),
                currentTask: availabilityMessage,
                focusTarget: AgentFocusTarget(
                    applicationBundleID: bundleIDs.first,
                    applicationName: appDisplayName,
                    workspacePath: nil,
                    terminalPreferred: bundleIDs.isEmpty
                )
            )
        ]
    }

    func openSession(sessionID: UUID) async -> AgentActionResult {
        if !bundleIDs.isEmpty {
            return await AppFocusService.shared.openApplication(
                bundleIDs: bundleIDs,
                fallbackName: appDisplayName
            )
        }
        return await AppFocusService.shared.focus(
            target: AgentFocusTarget(
                applicationBundleID: nil,
                applicationName: appDisplayName,
                workspacePath: nil,
                terminalPreferred: true
            )
        )
    }

    func focusSession(sessionID: UUID) async -> AgentActionResult {
        if AppFocusService.shared.activateRunning(bundleIDs: bundleIDs) {
            return .openedExternally
        }
        return await openSession(sessionID: sessionID)
    }
}
