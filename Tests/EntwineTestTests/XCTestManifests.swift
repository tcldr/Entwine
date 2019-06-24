import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(TestSchedulerTests.allTests),
        testCase(TestablePublisherTests.allTests),
        testCase(TestableSubscriberTests.allTests),
    ]
}
#endif
