//
//  AIIslandViews.swift
//  boringNotch
//
//  Expanded AI Island UI — matches Boring Notch density and chrome.
//

import Defaults
import SwiftUI

struct AIIslandView: View {
    @ObservedObject private var manager = AgentManager.shared
    @State private var planFeedback: String = ""

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            sessionList
                .frame(maxWidth: .infinity)
            if let session = manager.selectedSession {
                AgentDetailPane(session: session, planFeedback: $planFeedback)
                    .frame(width: 260)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
        .padding(.top, 4)
        .onAppear {
            manager.startIfNeeded()
        }
    }

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            filters
            if manager.displayedSessions.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 6) {
                        ForEach(manager.displayedSessions) { session in
                            AgentRowView(session: session, selected: manager.selectedSessionID == session.id) {
                                withAnimation(.smooth(duration: 0.25)) {
                                    manager.selectSession(
                                        manager.selectedSessionID == session.id ? nil : session.id
                                    )
                                }
                            }
                        }
                    }
                }
            }
            footerStats
        }
    }

    private var header: some View {
        HStack {
            Text("AI TEAM")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                Task { await manager.refreshAll() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private var filters: some View {
        HStack(spacing: 6) {
            ForEach(AgentSessionFilter.allCases) { filter in
                filterChip(
                    title: filter.label,
                    selected: manager.filter == filter
                ) {
                    manager.filter = filter
                }
            }
            Spacer(minLength: 0)
            Menu {
                Button("All Agents") { manager.agentFilter = nil }
                ForEach(AgentKind.allCases.filter { $0 != .mock }) { kind in
                    Button(kind.displayName) { manager.agentFilter = kind }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
        }
    }

    private func filterChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(selected ? Color(nsColor: .secondarySystemFill) : Color.clear)
                )
                .foregroundStyle(selected ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No agent sessions")
                .font(.system(.callout, design: .rounded).weight(.medium))
            Text("Enable agents in Settings → AI Island, or turn on Demo Mode.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 20)
    }

    private var footerStats: some View {
        HStack(spacing: 10) {
            Label("\(manager.attention.workingCount) Working", systemImage: "circle.fill")
                .foregroundStyle(manager.attention.workingCount > 0 ? .green : .secondary)
            Label("\(manager.attention.attentionCount) Attention", systemImage: "circle.fill")
                .foregroundStyle(manager.attention.attentionCount > 0 ? .orange : .secondary)
            Spacer()
        }
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .labelStyle(.titleAndIcon)
        .symbolRenderingMode(.hierarchical)
    }
}

struct AgentRowView: View {
    let session: AgentSession
    let selected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                statusDot
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(session.agent.displayName)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        Spacer()
                        Text(session.status.label)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(session.needsAttention ? Color.orange : Color.secondary)
                    }
                    Text(session.sessionName)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(session.summaryLine)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.85))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Color(nsColor: .secondarySystemFill) : Color.white.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }

    private var statusDot: some View {
        Circle()
            .fill(color(for: session.status))
            .frame(width: 8, height: 8)
    }

    private func color(for status: AgentStatus) -> Color {
        switch status {
        case .working, .starting: return .green
        case .permissionRequired, .question, .failed: return .red
        case .planReview, .waiting: return .orange
        case .completed: return .blue
        case .idle: return .gray
        case .disconnected: return .gray.opacity(0.5)
        }
    }
}

struct AgentDetailPane: View {
    let session: AgentSession
    @Binding var planFeedback: String
    @ObservedObject private var manager = AgentManager.shared

    private var caps: AgentCapabilities {
        manager.capabilities(for: session.agent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: session.agent.systemImage)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.agent.displayName)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text(session.sessionName)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    manager.selectSession(nil)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Label(session.status.label, systemImage: "circle.fill")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            if let task = session.currentTask {
                Text(task)
                    .font(.system(size: 12, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let request = session.permissionRequest {
                permissionBlock(request)
            }
            if let question = session.question {
                questionBlock(question)
            }
            if let plan = session.plan {
                planBlock(plan)
            }

            if !session.files.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Files")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(session.files.prefix(5), id: \.self) { file in
                        Text(file)
                            .font(.system(size: 11, design: .monospaced))
                    }
                }
            }

            if let usage = session.usage {
                usageBlock(usage)
            }

            if let error = session.lastError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.9))
            }

            actionRow
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.35))
        )
    }

    private func permissionBlock(_ request: AgentPermissionRequest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(request.title)
                .font(.system(size: 11, weight: .semibold))
            Text(request.detail)
                .font(.system(size: 11, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
            HStack {
                Button("Deny") {
                    Task { _ = await manager.respondToPermission(sessionID: session.id, allow: false) }
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("Allow") {
                    Task { _ = await manager.respondToPermission(sessionID: session.id, allow: true) }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            if !caps.supportsPermission {
                Text("Response cannot be sent to this agent — Allow/Deny updates local state only if Demo; otherwise Open Agent.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func questionBlock(_ question: AgentQuestion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(question.prompt)
                .font(.system(size: 12, weight: .medium))
            ForEach(question.options) { option in
                Button(option.label) {
                    Task { _ = await manager.answerQuestion(sessionID: session.id, optionID: option.id) }
                }
                .buttonStyle(.bordered)
            }
            if !caps.supportsQuestions {
                Button("Open Agent") {
                    Task { _ = await manager.openSession(session.id) }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func planBlock(_ plan: AgentPlan) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(plan.title)
                .font(.system(size: 11, weight: .semibold))
            ForEach(plan.steps.sorted(by: { $0.order < $1.order })) { step in
                Text("\(step.order). \(step.text)")
                    .font(.system(size: 11))
            }
            TextField("Feedback", text: $planFeedback)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
            HStack {
                Button("Reject") {
                    Task { _ = await manager.reviewPlan(sessionID: session.id, decision: .reject, feedback: nil) }
                }
                Button("Feedback") {
                    Task {
                        _ = await manager.reviewPlan(
                            sessionID: session.id,
                            decision: .feedback,
                            feedback: planFeedback
                        )
                    }
                }
                Spacer()
                Button("Approve") {
                    Task { _ = await manager.reviewPlan(sessionID: session.id, decision: .approve, feedback: nil) }
                }
                .buttonStyle(.borderedProminent)
            }
            .font(.system(size: 11))
        }
    }

    private func usageBlock(_ usage: AgentUsage) -> some View {
        Group {
            if let reason = usage.unavailableReason {
                Text(reason)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else {
                Text("\(usage.provider): \(usage.tokensUsed.map(String.init) ?? "—") tokens")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 6) {
            actionButton("Open") {
                Task { _ = await manager.openSession(session.id) }
            }
            actionButton("Focus") {
                Task { _ = await manager.focusSession(session.id) }
            }
            actionButton("Stop", disabled: !caps.supportsStop) {
                Task { _ = await manager.stopSession(session.id) }
            }
            if session.workspace.path != nil {
                actionButton("Project") {
                    _ = manager.openProject(for: session.id)
                }
            }
        }
    }

    private func actionButton(_ title: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color(nsColor: .secondarySystemFill)))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }
}

struct AIIslandCollapsedChip: View {
    @ObservedObject private var manager = AgentManager.shared

    var body: some View {
        Group {
            if Defaults[.aiIslandEnabled], manager.attention.totalCount > 0 || manager.attention.attentionCount > 0 {
                HStack(spacing: 4) {
                    Circle()
                        .fill(manager.attention.collapsedNeedsAttention ? Color.red : Color.green)
                        .frame(width: 6, height: 6)
                    if manager.attention.attentionCount > 0 && manager.attention.workingCount > 0 {
                        Text("\(manager.attention.workingCount)")
                            .foregroundStyle(.green)
                        Text("\(manager.attention.attentionCount)")
                            .foregroundStyle(.red)
                    } else {
                        Text(manager.attention.collapsedLabel)
                    }
                }
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
            }
        }
        .onAppear { manager.startIfNeeded() }
    }
}
