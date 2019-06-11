
import XCTest
import Combine

@testable import TestScheduler

final class TestablePublisherTests: XCTestCase {
    
    struct Token: Equatable {}
    
    func testColdObservableProducesExpectedValues() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let testablePublisher: TestablePublisher<Token, Never> = testScheduler.createTestableColdPublisher([
            .init(time:   0, .init()),
            .init(time: 200, .init()),
            .init(time: 400, .init()),
        ])
        
        let testableSubscriber = testScheduler.start { testablePublisher }
        
        let expected: [TestableSubscriberEvent<Token, Never>] = [
            .init(200, .subscribe),
            .init(200, .input(.init())),
            .init(400, .input(.init())),
            .init(600, .input(.init())),
            .init(900, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected, testableSubscriber.events)
    }
    
    func testHotObservableProducesExpectedValues() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let testablePublisher: TestablePublisher<Token, Never> = testScheduler.createTestableHotPublisher([
            .init(time:   0, .init()),
            .init(time: 200, .init()),
            .init(time: 400, .init()),
        ])
        
        let testableSubscriber = testScheduler.start { testablePublisher }
        
        let expected: [TestableSubscriberEvent<Token, Never>] = [
            .init(200, .subscribe),
            .init(200, .input(.init())),
            .init(400, .input(.init())),
            .init(900, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected, testableSubscriber.events)
    }
    
    static var allTests = [
        ("testColdObservableProducesExpectedValues", testColdObservableProducesExpectedValues),
        ("testHotObservableProducesExpectedValues", testHotObservableProducesExpectedValues),
    ]
}
