#!/usr/bin/env swift
import Foundation

enum AgentStatus: String {
    case idle, starting, working, waiting, permissionRequired, question, planReview, completed, failed, disconnected
    var needsAttention: Bool {
        [.permissionRequired, .question, .failed, .planReview].contains(self)
    }
    var attentionPriority: Int {
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

struct Session {
    var status: AgentStatus
    var updatedAt: Date = Date()
}

func sorted(_ sessions: [Session]) -> [Session] {
    sessions.sorted {
        if $0.status.attentionPriority != $1.status.attentionPriority {
            return $0.status.attentionPriority < $1.status.attentionPriority
        }
        return $0.updatedAt > $1.updatedAt
    }
}

var failed = 0
func expect(_ cond: Bool, _ msg: String) {
    if !cond {
        fputs("FAIL: \(msg)\n", stderr)
        failed += 1
    } else {
        print("OK: \(msg)")
    }
}

let ordered = sorted([
    Session(status: .working),
    Session(status: .permissionRequired),
    Session(status: .completed),
    Session(status: .failed)
]).map(\.status)
expect(ordered == [.permissionRequired, .failed, .completed, .working], "permission first")

let sessions = [
    Session(status: .working),
    Session(status: .starting),
    Session(status: .question),
    Session(status: .completed),
    Session(status: .idle)
]
let working = sessions.filter { $0.status == .working || $0.status == .starting }.count
let attention = sessions.filter(\.status.needsAttention).count
expect(working == 2, "working count")
expect(attention == 1, "attention count")

if failed > 0 {
    fputs("\(failed) test(s) failed\n", stderr)
    exit(1)
}
print("All attention tests passed")
