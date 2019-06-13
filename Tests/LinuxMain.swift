import XCTest

import TestSchedulerTests

var tests: [XCTestCaseEntry] = [
    BufferTests.allTests,
    MyMapTests.allTests,
    ReplaySubjectTests.allTests,
    WithLatestFromTests.allTests,
    TestablePublisherTests.allTests,
    TestableSubscriberTests.allTests,
    TestSchedulerTests.allTests,
]

XCTMain(tests)
