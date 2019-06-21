
import XCTest
import Combine

@testable import Entwine
@testable import EntwineTest

final class TestablePublisherTests: XCTestCase {
    
    struct Token: Equatable {}
    
    func testColdObservableProducesExpectedValues() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let testablePublisher: TestablePublisher<Token, Never> = testScheduler.createTestableColdPublisher([
            .input(  0, .init()),
            .input(200, .init()),
            .input(400, .init()),
        ])
        
        let testableSubscriber = testScheduler.start { testablePublisher }
        
        XCTAssertEqual(testableSubscriber.events, [
            .init(200, .subscription),
            .init(200, .input(.init())),
            .init(400, .input(.init())),
            .init(600, .input(.init())),
            .init(900, .completion(.finished)),
        ])
    }
    
    func testHotObservableProducesExpectedValues() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let testablePublisher: TestablePublisher<Token, Never> = testScheduler.createTestableHotPublisher([
            .input(  0, .init()),
            .input(200, .init()),
            .input(400, .init()),
        ])
        
        let testableSubscriber = testScheduler.start { testablePublisher }
        
        XCTAssertEqual(testableSubscriber.events, [
            .init(200, .subscription),
            .init(200, .input(.init())),
            .init(400, .input(.init())),
            .init(900, .completion(.finished)),
        ])
    }
    
    static var allTests = [
        ("testColdObservableProducesExpectedValues", testColdObservableProducesExpectedValues),
        ("testHotObservableProducesExpectedValues", testHotObservableProducesExpectedValues),
    ]
}
