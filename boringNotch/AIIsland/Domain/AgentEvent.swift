//
//  AgentEvent.swift
//  boringNotch
//

import Foundation

enum AgentEvent: Equatable {
    case sessionsUpdated(agent: AgentKind)
    case statusChanged(sessionID: UUID, status: AgentStatus)
    case permissionRequested(sessionID: UUID)
    case questionAsked(sessionID: UUID)
    case planReady(sessionID: UUID)
    case completed(sessionID: UUID)
    case failed(sessionID: UUID, message: String)
    case disconnected(agent: AgentKind)
    case integrationUnavailable(agent: AgentKind, reason: String)
}

struct AgentAttentionSummary: Equatable {
    var workingCount: Int
    var attentionCount: Int
    var completedCount: Int
    var totalCount: Int
    var topPrioritySession: AgentSession?

    var collapsedLabel: String {
        if attentionCount > 0 && workingCount > 0 {
            return "\(workingCount)  \(attentionCount)"
        }
        if attentionCount > 0 {
            return "\(attentionCount)"
        }
        if totalCount == 0 {
            return "0"
        }
        return "\(totalCount)"
    }

    var collapsedNeedsAttention: Bool {
        attentionCount > 0
    }
}

enum AgentAttention {
    static func summarize(_ sessions: [AgentSession]) -> AgentAttentionSummary {
        let working = sessions.filter { $0.status == .working || $0.status == .starting }.count
        let attention = sessions.filter(\.needsAttention).count
        let completed = sessions.filter { $0.status == .completed }.count
        let top = sessions
            .sorted { lhs, rhs in
                if lhs.status.attentionPriority != rhs.status.attentionPriority {
                    return lhs.status.attentionPriority < rhs.status.attentionPriority
                }
                return lhs.updatedAt > rhs.updatedAt
            }
            .first
        return AgentAttentionSummary(
            workingCount: working,
            attentionCount: attention,
            completedCount: completed,
            totalCount: sessions.count,
            topPrioritySession: top
        )
    }

    static func filter(_ sessions: [AgentSession], by filter: AgentSessionFilter) -> [AgentSession] {
        switch filter {
        case .all:
            return sessions
        case .working:
            return sessions.filter { $0.status == .working || $0.status == .starting || $0.status == .waiting }
        case .needsAttention:
            return sessions.filter(\.needsAttention)
        case .completed:
            return sessions.filter { $0.status == .completed }
        }
    }

    static func sortedForDisplay(_ sessions: [AgentSession]) -> [AgentSession] {
        sessions.sorted { lhs, rhs in
            if lhs.status.attentionPriority != rhs.status.attentionPriority {
                return lhs.status.attentionPriority < rhs.status.attentionPriority
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }
}
