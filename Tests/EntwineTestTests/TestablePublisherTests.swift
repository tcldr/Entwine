
import XCTest
import Combine

@testable import Entwine
@testable import EntwineTest

final class TestablePublisherTests: XCTestCase {
    
    struct Token: Equatable {}
    
    func testColdObservableProducesExpectedValues() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let testablePublisher: TestablePublisher<Token, Never> = testScheduler.createTestableColdPublisher([
            (  0, .input(.init())),
            (200, .input(.init())),
            (400, .input(.init())),
        ])
        
        let testableSubscriber = testScheduler.start { testablePublisher }
        
        XCTAssertEqual(testableSubscriber.sequence, [
            (200, .subscription),
            (200, .input(.init())),
            (400, .input(.init())),
            (600, .input(.init())),
            (900, .completion(.finished)),
        ])
    }
    
    func testHotObservableProducesExpectedValues() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let testablePublisher: TestablePublisher<Token, Never> = testScheduler.createTestableHotPublisher([
            (  0, .input(.init())),
            (200, .input(.init())),
            (400, .input(.init())),
        ])
        
        let testableSubscriber = testScheduler.start { testablePublisher }
        
        XCTAssertEqual(testableSubscriber.sequence, [
            (200, .subscription),
            (200, .input(.init())),
            (400, .input(.init())),
            (900, .completion(.finished)),
        ])
    }
    
    static var allTests = [
        ("testColdObservableProducesExpectedValues", testColdObservableProducesExpectedValues),
        ("testHotObservableProducesExpectedValues", testHotObservableProducesExpectedValues),
    ]
}
