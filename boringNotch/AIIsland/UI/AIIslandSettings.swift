//
//  AIIslandSettings.swift
//  boringNotch
//

import Defaults
import SwiftUI

struct AIIslandSettings: View {
    @Default(.aiIslandEnabled) private var enabled
    @Default(.aiIslandDemoMode) private var demoMode
    @Default(.aiIslandNotifications) private var notifications
    @Default(.aiIslandShowCollapsedChip) private var showChip
    @Default(.aiIslandEnabledAgents) private var enabledAgents
    @ObservedObject private var manager = AgentManager.shared

    var body: some View {
        Form {
            Section {
                Defaults.Toggle("Enable AI Island", key: .aiIslandEnabled)
                Defaults.Toggle("Show collapsed attention chip", key: .aiIslandShowCollapsedChip)
                Defaults.Toggle("Attention sneak peeks", key: .aiIslandNotifications)
            } header: {
                Text("AI Island")
            } footer: {
                Text("AI Island adds a native multi-agent dashboard inside the notch. Existing Boring Notch features stay unchanged.")
            }

            Section {
                Defaults.Toggle("Demo Mode (Mock Agent)", key: .aiIslandDemoMode)
                if demoMode {
                    HStack {
                        Button("Mixed") { manager.loadMockScenario(.mixed) }
                        Button("Permission") { manager.loadMockScenario(.permission) }
                        Button("Question") { manager.loadMockScenario(.question) }
                        Button("Plan") { manager.loadMockScenario(.plan) }
                        Button("Failed") { manager.loadMockScenario(.failed) }
                    }
                }
            } header: {
                Text("Demo")
            } footer: {
                Text("Demo Mode is for UI testing only. It does not claim live agent integration.")
            }
            .onChange(of: demoMode) { _, _ in
                NotificationCenter.default.post(name: .aiIslandDemoModeChanged, object: nil)
            }
            .onChange(of: enabled) { _, _ in
                NotificationCenter.default.post(name: .aiIslandDemoModeChanged, object: nil)
            }

            Section {
                ForEach(AgentKind.allCases.filter { $0 != .mock }) { kind in
                    Toggle(isOn: binding(for: kind)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.displayName)
                            Text(manager.adapterStatuses[kind] ?? "Not started")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Agents")
            } footer: {
                Text("Adapters detect local apps/CLIs only. Permission/plan bridges appear when an agent exposes a supported local channel — otherwise Open/Focus is used.")
            }
            .onChange(of: enabledAgents) { _, _ in
                NotificationCenter.default.post(name: .aiIslandDemoModeChanged, object: nil)
            }

            Section {
                Text("Security")
                    .font(.headline)
                Text("• Never auto-approves commands\n• Never reads API keys or credentials\n• Never uploads source or logs\n• Focus uses NSWorkspace / optional Apple Events")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { manager.startIfNeeded() }
    }

    private func binding(for kind: AgentKind) -> Binding<Bool> {
        Binding(
            get: { enabledAgents.contains(kind.rawValue) },
            set: { isOn in
                var next = enabledAgents
                if isOn {
                    if !next.contains(kind.rawValue) { next.append(kind.rawValue) }
                } else {
                    next.removeAll { $0 == kind.rawValue }
                }
                enabledAgents = next
            }
        )
    }
}
