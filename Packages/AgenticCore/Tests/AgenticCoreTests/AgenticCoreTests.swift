import Testing

@testable import AgenticCore

@Test func testCopilotPlanLimits() async throws {
    #expect(CopilotPlan.free.limit == 50)
    #expect(CopilotPlan.pro.limit == 300)
    #expect(CopilotPlan.proPlus.limit == 1500)
}
