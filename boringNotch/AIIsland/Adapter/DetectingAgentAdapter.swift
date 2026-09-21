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
    private let appNames: [String]
    private let cliNames: [String]
    private let processNames: [String]
    private let commandLineNeedles: [String]
    private let supportPaths: [String]
    private let appDisplayName: String
    private var refreshTask: Task<Void, Never>?
    /// Stable row identity across polls. Key = agent + session name + workspace path.
    private var sessionIDsByKey: [String: UUID] = [:]

    init(
        kind: AgentKind,
        bundleIDs: [String] = [],
        appNames: [String] = [],
        cliNames: [String] = [],
        processNames: [String] = [],
        commandLineNeedles: [String] = [],
        supportPaths: [String] = [],
        appDisplayName: String,
        baseCapabilities: AgentCapabilities = .openOnly
    ) {
        self.kind = kind
        self.bundleIDs = bundleIDs
        self.appNames = appNames
        self.cliNames = cliNames
        self.processNames = processNames
        self.commandLineNeedles = commandLineNeedles
        self.supportPaths = supportPaths
        self.appDisplayName = appDisplayName
        var caps = baseCapabilities
        caps.supportsOpenApp = true
        caps.supportsTerminalFocus = !bundleIDs.isEmpty || !cliNames.isEmpty || !commandLineNeedles.isEmpty
        self.capabilities = caps
    }

    func startObserving() async {
        await refresh()
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await self?.refresh()
            }
        }
    }

    func stopObserving() async {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() async {
        // Process scanning must not block the MainActor (pipe deadlock freezes the notch UI).
        let bundleIDs = self.bundleIDs
        let appNames = self.appNames
        let processNames = self.processNames
        let commandLineNeedles = self.commandLineNeedles
        let cliNames = self.cliNames
        let supportPaths = self.supportPaths
        let appDisplayName = self.appDisplayName

        let snapshot = await Task.detached(priority: .utility) {
            let appRunning =
                (!bundleIDs.isEmpty && ProcessDetection.isAppRunning(bundleIdentifiers: bundleIDs))
                || (!appNames.isEmpty && ProcessDetection.isAppRunning(named: appNames))
            let cliProcessRunning = !processNames.isEmpty && ProcessDetection.isProcessRunning(exactNames: processNames)
            let terminalRunning = !commandLineNeedles.isEmpty
                && ProcessDetection.commandLineContainsAny(of: commandLineNeedles)
            let cliURL = cliNames.compactMap { ProcessDetection.which($0) }.first
            let supportHit = supportPaths.contains { ProcessDetection.directoryExists($0) }
            let matchCmd = terminalRunning
                ? ProcessDetection.firstMatchingCommandLine(of: commandLineNeedles)
                : nil
            return (appRunning, cliProcessRunning, terminalRunning, cliURL, supportHit, matchCmd)
        }.value

        let appRunning = snapshot.0
        let cliProcessRunning = snapshot.1
        let terminalRunning = snapshot.2
        let cliURL = snapshot.3
        let supportHit = snapshot.4
        let matchCmd = snapshot.5
        let active = appRunning || cliProcessRunning || terminalRunning

        isAvailable = active || cliURL != nil || supportHit

        if terminalRunning {
            availabilityMessage = matchCmd.map { "Terminal: \($0)" } ?? "\(appDisplayName) running in terminal"
        } else if appRunning {
            availabilityMessage = "\(appDisplayName) app is open"
        } else if cliProcessRunning {
            availabilityMessage = "\(appDisplayName) process is running"
        } else if cliURL != nil {
            availabilityMessage = "Ready — CLI at \(cliURL!.path)"
        } else if supportHit {
            availabilityMessage = "Installed (no live session)"
        } else {
            availabilityMessage = "\(appDisplayName) not detected"
        }

        var caps = capabilities
        caps.supportsOpenApp = true
        caps.supportsTerminalFocus = active || cliURL != nil
        caps.supportsPermission = false
        caps.supportsQuestions = false
        caps.supportsPlanReview = false
        caps.supportsUsage = false
        caps.supportsSessionControl = false
        caps.supportsStop = false
        caps.supportsRestart = false
        capabilities = caps

        let sessions = buildSessions(
            appRunning: appRunning,
            cliProcessRunning: cliProcessRunning || terminalRunning,
            cliPresent: cliURL != nil
        )
        publishIfChanged(sessions)
    }

    /// Reuse ids and skip the publisher when nothing the UI cares about changed.
    /// `updatedAt` is a fresh `Date()` on every build, so it must not count.
    private func publishIfChanged(_ sessions: [AgentSession]) {
        let stable = stabilizeIdentities(sessions)
        let previous = subject.value
        guard !sessionsMatchIgnoringTimestamp(previous, stable) else { return }
        subject.send(stable)
    }

    private func stabilizeIdentities(_ sessions: [AgentSession]) -> [AgentSession] {
        var occurrence: [String: Int] = [:]
        var used: Set<String> = []
        let stable = sessions.map { session -> AgentSession in
            let base = "\(session.agent.rawValue)|\(session.sessionName)|\(session.workspace.path ?? "")"
            let n = occurrence[base, default: 0]
            occurrence[base] = n + 1
            let key = n == 0 ? base : "\(base)#\(n)"
            used.insert(key)
            var copy = session
            if let existing = sessionIDsByKey[key] {
                copy.id = existing
            } else {
                sessionIDsByKey[key] = copy.id
            }
            return copy
        }
        sessionIDsByKey = sessionIDsByKey.filter { used.contains($0.key) }
        return stable
    }

    private func sessionsMatchIgnoringTimestamp(_ lhs: [AgentSession], _ rhs: [AgentSession]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { left, right in
            var copy = left
            copy.updatedAt = right.updatedAt
            return copy == right
        }
    }

    func updateAvailability(_ available: Bool, message: String?) {
        isAvailable = available
        availabilityMessage = message
    }

    /// Subclasses override to attach real workspace evidence when available.
    func buildSessions(appRunning: Bool, cliProcessRunning: Bool, cliPresent: Bool) -> [AgentSession] {
        guard isAvailable else { return [] }

        let status: AgentStatus
        let task: String
        if cliProcessRunning {
            status = .working
            task = availabilityMessage ?? "\(appDisplayName) is running"
        } else if appRunning {
            status = .idle
            task = "Ready"
        } else if cliPresent {
            status = .idle
            task = availabilityMessage ?? "CLI ready"
        } else {
            status = .idle
            task = availabilityMessage ?? "Installed"
        }

        return [
            AgentSession(
                agent: kind,
                sessionName: "Default",
                status: status,
                workspace: AgentWorkspace(projectName: appDisplayName, path: nil),
                currentTask: task,
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
        if let app = ProcessDetection.runningApp(named: appNames),
           app.activate(options: [.activateIgnoringOtherApps]) {
            return .openedExternally
        }
        return await openSession(sessionID: sessionID)
    }
}
