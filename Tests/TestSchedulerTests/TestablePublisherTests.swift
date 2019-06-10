
import XCTest
import Combine

@testable import TestScheduler

final class TestablePublisherTests: XCTestCase {
    
    struct Token: Equatable {}
    
    func testColdObservableProducesExpectedValues() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let testablePublisher: TestablePublisher<Token, Never> = testScheduler.createTestableColdPublisher([
            .init(time: 0, .init()),
            .init(time: 200, .init()),
            .init(time: 400, .init()),
        ])
        
        let testableSubscriber = testScheduler.start { testablePublisher }
        
        let expected: [TestableSubscriberEvent<Token, Never>] = [
            .subscribe(time: 200),
            .input(time: 200, .init()),
            .input(time: 400, .init()),
            .input(time: 600, .init()),
            .completion(time: 1000, .finished)
        ]
        
        XCTAssertEqual(expected, testableSubscriber.events)
    }
    
    func testHotObservableProducesExpectedValues() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let testablePublisher: TestablePublisher<Token, Never> = testScheduler.createTestableHotPublisher([
            .init(time: 0, .init()),
            .init(time: 200, .init()),
            .init(time: 400, .init()),
        ])
        
        let testableSubscriber = testScheduler.start { testablePublisher }
        
        let expected: [TestableSubscriberEvent<Token, Never>] = [
            .subscribe(time: 200),
            .input(time: 200, .init()),
            .input(time: 400, .init()),
            .completion(time: 1000, .finished)
        ]
        
        XCTAssertEqual(expected, testableSubscriber.events)
    }
    
    static var allTests = [
        ("testColdObservableProducesExpectedValues", testColdObservableProducesExpectedValues),
        ("testHotObservableProducesExpectedValues", testHotObservableProducesExpectedValues),
    ]
}
