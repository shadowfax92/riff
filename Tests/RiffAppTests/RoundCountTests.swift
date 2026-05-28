import Testing
@testable import RiffApp

@Test func roundCountPreservesValuesAboveStepperOldLimit() {
    #expect(RoundCount.normalized(42) == 42)
}

@Test func roundCountClampsValuesBelowOne() {
    #expect(RoundCount.normalized(0) == 1)
    #expect(RoundCount.normalized(-5) == 1)
}
