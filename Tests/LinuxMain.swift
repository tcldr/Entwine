import XCTest

import TestSchedulerTests

var tests: [XCTestCaseEntry] = [
    TestSchedulerTests.allTests,
    TestableSubscriberTests.allTests,
    TestablePublisherTests.allTests,
]

XCTMain(tests)
