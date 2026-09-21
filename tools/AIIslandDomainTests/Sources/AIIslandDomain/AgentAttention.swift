import Foundation

public enum AgentStatus: String, Sendable {
    case idle, starting, working, waiting, permissionRequired, question, planReview, completed, failed, disconnected

    public var needsAttention: Bool {
        switch self {
        case .permissionRequired, .question, .failed, .planReview: return true
        default: return false
        }
    }

    public var attentionPriority: Int {
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
}

public struct AgentSessionStub: Identifiable, Sendable {
    public var id: UUID
    public var status: AgentStatus
    public var updatedAt: Date

    public init(id: UUID = UUID(), status: AgentStatus, updatedAt: Date = Date()) {
        self.id = id
        self.status = status
        self.updatedAt = updatedAt
    }

    public var needsAttention: Bool { status.needsAttention }
}

public enum AgentSessionFilter: String, Sendable {
    case all, working, needsAttention, completed
}

public struct AgentAttentionSummary: Equatable, Sendable {
    public var workingCount: Int
    public var attentionCount: Int
    public var completedCount: Int
    public var totalCount: Int
}

public enum AgentAttention {
    public static func summarize(_ sessions: [AgentSessionStub]) -> AgentAttentionSummary {
        AgentAttentionSummary(
            workingCount: sessions.filter { $0.status == .working || $0.status == .starting }.count,
            attentionCount: sessions.filter(\.needsAttention).count,
            completedCount: sessions.filter { $0.status == .completed }.count,
            totalCount: sessions.count
        )
    }

    public static func filter(_ sessions: [AgentSessionStub], by filter: AgentSessionFilter) -> [AgentSessionStub] {
        switch filter {
        case .all: return sessions
        case .working: return sessions.filter { $0.status == .working || $0.status == .starting || $0.status == .waiting }
        case .needsAttention: return sessions.filter(\.needsAttention)
        case .completed: return sessions.filter { $0.status == .completed }
        }
    }

    public static func sortedForDisplay(_ sessions: [AgentSessionStub]) -> [AgentSessionStub] {
        sessions.sorted { lhs, rhs in
            if lhs.status.attentionPriority != rhs.status.attentionPriority {
                return lhs.status.attentionPriority < rhs.status.attentionPriority
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }
}
