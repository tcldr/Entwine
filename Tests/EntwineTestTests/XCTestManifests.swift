import XCTest

#if !canImport(ObjectiveC) && canImport(Combine)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(TestSchedulerTests.allTests),
        testCase(TestablePublisherTests.allTests),
        testCase(TestableSubscriberTests.allTests),
    ]
}
#endif
