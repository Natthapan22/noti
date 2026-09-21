import XCTest
@testable import AIIslandDomain

final class AgentAttentionTests: XCTestCase {
    func testPriorityOrdersPermissionFirst() {
        let sessions = [
            AgentSessionStub(status: .working),
            AgentSessionStub(status: .permissionRequired),
            AgentSessionStub(status: .completed),
            AgentSessionStub(status: .failed)
        ]
        let sorted = AgentAttention.sortedForDisplay(sessions)
        XCTAssertEqual(sorted.map(\.status), [.permissionRequired, .failed, .completed, .working])
    }

    func testSummarizeCounts() {
        let sessions = [
            AgentSessionStub(status: .working),
            AgentSessionStub(status: .starting),
            AgentSessionStub(status: .question),
            AgentSessionStub(status: .completed),
            AgentSessionStub(status: .idle)
        ]
        let summary = AgentAttention.summarize(sessions)
        XCTAssertEqual(summary.workingCount, 2)
        XCTAssertEqual(summary.attentionCount, 1)
        XCTAssertEqual(summary.completedCount, 1)
        XCTAssertEqual(summary.totalCount, 5)
    }

    func testNeedsAttentionFilter() {
        let sessions = [
            AgentSessionStub(status: .idle),
            AgentSessionStub(status: .planReview),
            AgentSessionStub(status: .failed)
        ]
        let filtered = AgentAttention.filter(sessions, by: .needsAttention)
        XCTAssertEqual(filtered.count, 2)
    }

    func testAdapterFailureDoesNotAffectOtherSessions() {
        // Simulates merge isolation: one failed session still leaves others countable
        let sessions = [
            AgentSessionStub(status: .failed),
            AgentSessionStub(status: .working)
        ]
        let summary = AgentAttention.summarize(sessions)
        XCTAssertEqual(summary.workingCount, 1)
        XCTAssertEqual(summary.attentionCount, 1)
    }
}
