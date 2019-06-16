//
//  File.swift
//  
//
//  Created by Tristan Celder on 09/06/2019.
//

import XCTest
import Combine

@testable import Entwine
@testable import EntwineTest

final class WithLatestFromTests: XCTestCase {
    
    func testTakesOnlyLatestValueFromOther() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let testablePublisher: TestablePublisher<String, Never> = testScheduler.createTestableColdPublisher([
            .init(time: 10, "x"),
            .init(time: 20, "y"),
            .init(time: 30, "z"),
        ])
        
        let testablePublisherOther: TestablePublisher<String, Never> = testScheduler.createTestableColdPublisher([
            .init(time: 1, "a"),
            .init(time: 2, "b"),
            .init(time: 3, "c"),
        ])
        
        let testableSubscriber = testScheduler.start { testablePublisher.withLatest(from: testablePublisherOther)  }
        
        let expected: [TestableSubscriberEvent<String, Never>] = [
            .init(200, .subscribe),
            .init(210, .input("c")),
            .init(220, .input("c")),
            .init(230, .input("c")),
            .init(900, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected, testableSubscriber.events)
    }
    
    func testDropsUpstreamValuesReceivedPriorToFirstOtherValue() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let testablePublisher: TestablePublisher<String, Never> = testScheduler.createTestableColdPublisher([
            .init(time: 10, "x"),
            .init(time: 20, "y"),
            .init(time: 30, "z"),
        ])
        
        let testablePublisherOther: TestablePublisher<String, Never> = testScheduler.createTestableColdPublisher([
            .init(time: 15, "a"),
            .init(time: 25, "b"),
            .init(time: 35, "c"),
        ])
        
        let testableSubscriber = testScheduler.start { testablePublisher.withLatest(from: testablePublisherOther)  }
        
        let expected: [TestableSubscriberEvent<String, Never>] = [
            .init(200, .subscribe),
            .init(220, .input("a")),
            .init(230, .input("b")),
            .init(900, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected, testableSubscriber.events)
    }
    
    func testMatchesLimitedSubscriberDemand() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let testablePublisher: TestablePublisher<String, Never> = testScheduler.createTestableColdPublisher([
            .init(time: 10, "x"),
            .init(time: 20, "y"),
            .init(time: 30, "z"),
        ])
        
        let testablePublisherOther: TestablePublisher<String, Never> = testScheduler.createTestableColdPublisher([
            .init(time: 0, "a"),
            .init(time: 1, "b"),
            .init(time: 2, "c"),
        ])
        
        var configuration = TestScheduler.Configuration.default
        configuration.subscriberOptions.initialDemand = .max(1)
        
        let testableSubscriber = testScheduler.start(configuration: configuration) { testablePublisher.withLatest(from: testablePublisherOther)  }
        
        let expected: [TestableSubscriberEvent<String, Never>] = [
            .init(200, .subscribe),
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
        scheduler.schedule(after: 500) { results1.terminateSubscription() }
        scheduler.schedule(after: 600) { XCTAssertEqual(0, publisher1.subscriptionCount) }
        scheduler.schedule(after: 600) { XCTAssertEqual(0, publisher2.subscriptionCount) }
        
        scheduler.resume()
        
    }

    static var allTests = [
        ("testTakesLatestValueFromOther", testTakesOnlyLatestValueFromOther),
        ("testDropsUpstreamValuesReceivedPriorToFirstOtherValue", testDropsUpstreamValuesReceivedPriorToFirstOtherValue),
        ("testMatchesLimitedSubscriberDemand", testMatchesLimitedSubscriberDemand),
        ("testCancelsUpstreamSubscriptions", testCancelsUpstreamSubscriptions)
    ]
}
