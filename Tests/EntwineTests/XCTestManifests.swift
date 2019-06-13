import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(MyMapTests.allTests),
        testCase(ReplaySubjectTests.allTests),
    ]
}
#endif
