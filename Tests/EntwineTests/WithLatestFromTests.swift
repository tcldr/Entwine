
import XCTest
import Combine

@testable import Entwine
@testable import EntwineTest

final class WithLatestFromTests: XCTestCase {
    
    func testTakesOnlyLatestValueFromOther() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let testablePublisher: TestablePublisher<String, Never> = testScheduler.createTestableColdPublisher([
            .input(10, "x"),
            .input(20, "y"),
            .input(30, "z"),
        ])
        
        let testablePublisherOther: TestablePublisher<String, Never> = testScheduler.createTestableColdPublisher([
            .input(1, "a"),
            .input(2, "b"),
            .input(3, "c"),
        ])
        
        let testableSubscriber = testScheduler.start { testablePublisher.withLatest(from: testablePublisherOther)  }
        
        let expected: [SignalEvent<Signal<String, Never>>] = [
            .subscription(200),
            .input(210, "c"),
            .input(220, "c"),
            .input(230, "c"),
            .completion(900, .finished),
        ]
        
        XCTAssertEqual(expected, testableSubscriber.events)
    }
    
    func testDropsUpstreamValuesReceivedPriorToFirstOtherValue() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let testablePublisher: TestablePublisher<String, Never> = testScheduler.createTestableColdPublisher([
            .input(10, "x"),
            .input(20, "y"),
            .input(30, "z"),
        ])
        
        let testablePublisherOther: TestablePublisher<String, Never> = testScheduler.createTestableColdPublisher([
            .input(15, "a"),
            .input(25, "b"),
            .input(35, "c"),
        ])
        
        let testableSubscriber = testScheduler.start { testablePublisher.withLatest(from: testablePublisherOther)  }
        
        let expected: [SignalEvent<Signal<String, Never>>] = [
            .init(200, .subscription),
            .init(220, .input("a")),
            .init(230, .input("b")),
            .init(900, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected, testableSubscriber.events)
    }
    
    func testMatchesLimitedSubscriberDemand() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let testablePublisher: TestablePublisher<String, Never> = testScheduler.createTestableColdPublisher([
            .input(10, "x"),
            .input(20, "y"),
            .input(30, "z"),
        ])
        
        let testablePublisherOther: TestablePublisher<String, Never> = testScheduler.createTestableColdPublisher([
            .input(0, "a"),
            .input(1, "b"),
            .input(2, "c"),
        ])
        
        var configuration = TestScheduler.Configuration.default
        configuration.subscriberOptions.initialDemand = .max(1)
        
        let testableSubscriber = testScheduler.start(configuration: configuration) { testablePublisher.withLatest(from: testablePublisherOther)  }
        
        let expected: [SignalEvent<Signal<String, Never>>] = [
            .init(200, .subscription),
            .init(210, .input("c")),
            .init(900, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected, testableSubscriber.events)
    }
    
    func testCancelsUpstreamSubscriptions() {
        
        let scheduler = TestScheduler(initialClock: 0)
        
        let publisher1 = ReplaySubject<Int, Never>(maxBufferSize: 0)
        let publisher2 = ReplaySubject<Int, Never>(maxBufferSize: 0)
        
        var subject: Publishers.WithLatestFrom<ReplaySubject<Int, Never>, ReplaySubject<Int, Never>, Int>!
        
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 100) { subject = Publishers.WithLatestFrom(upstream: publisher1, other: publisher2, transform: { _, b in b }) }
        scheduler.schedule(after: 200) { XCTAssertEqual(0, publisher1.subscriptionCount) }
        scheduler.schedule(after: 200) { XCTAssertEqual(0, publisher2.subscriptionCount) }
        scheduler.schedule(after: 300) { subject.subscribe(results1) }
        scheduler.schedule(after: 400) { XCTAssertEqual(1, publisher1.subscriptionCount) }
        scheduler.schedule(after: 400) { XCTAssertEqual(1, publisher2.subscriptionCount) }
        scheduler.schedule(after: 500) { results1.cancel() }
        scheduler.schedule(after: 600) { XCTAssertEqual(0, publisher1.subscriptionCount) }
        scheduler.schedule(after: 600) { XCTAssertEqual(0, publisher2.subscriptionCount) }
        
        scheduler.resume()
        
    }
}
