import XCTest
@testable import TestScheduler

final class TestSchedulerTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(TestScheduler().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
