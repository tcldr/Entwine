
import XCTest
import Combine

@testable import TestScheduler

final class TestableSubscriberTests: XCTestCase {
    
    struct Token: Equatable {}
    
    func testSubscriberObeysInitialDemandLimit() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        var testConfiguration = TestScheduler.Configuration.default
        testConfiguration.subscriberOptions.initialDemand = .none
        
        let testablePublisher: TestablePublisher<Token, Never> = testScheduler.createTestableColdPublisher([
            
            // Won't be delivered
            
            .init(time: 100, .init()),
            .init(time: 200, .init()),
            .init(time: 300, .init()),
        ])
        
        let testableSubscriber = testScheduler.start(configuration: testConfiguration) { testablePublisher }
        
        let expected: [TestableSubscriberEvent<Token, Never>] = [
            .init(200, .subscribe),
            .init(900, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected, testableSubscriber.events)
        
        let expectedDemandLedger: [DemandLedgerRow<VirtualTime>] = [
            .init(200, .credit(amount: .none), balance: .none)
        ]
        
        XCTAssertEqual(expectedDemandLedger, testableSubscriber.demands)
    }
    
    func testSubscriberObeysSubsequentDemandLimit() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        var testConfiguration = TestScheduler.Configuration.default
        testConfiguration.subscriberOptions.initialDemand = .none
        testConfiguration.subscriberOptions.subsequentDemand = .unlimited
        
        let testablePublisher: TestablePublisher<Token, Never> = testScheduler.createTestableColdPublisher([
            
            // Will all be deliverd at once when demand is replenished at (subscribe time + .demandReplenishDelay).
            
            // If inital demand was available the events would be delivered at 210, 220, and 230 respectively.
            // Howver, on subscription the initial demand is zero, so the TestableSubscriber schedules demand
            // to be replenished 100 in the future – at 300. When the demand is finally requested
            // the buffered values are delivered immediately.
            
            .init(time: 10, .init()),
            .init(time: 20, .init()),
            .init(time: 30, .init()),
        ])
        
        let testableSubscriber = testScheduler.start(configuration: testConfiguration) { testablePublisher }
        
        let expected: [TestableSubscriberEvent<Token, Never>] = [
            .init(200, .subscribe),
            .init(300, .input(.init())),
            .init(300, .input(.init())),
            .init(300, .input(.init())),
            .init(900, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected, testableSubscriber.events)
        
        let expectedDemandLedger: [DemandLedgerRow<VirtualTime>] = [
            .init(200, .credit(amount: .none),      balance: .none),
            .init(300, .credit(amount: .unlimited), balance: .unlimited),
            .init(300, .debit(authorized: true),    balance: .unlimited),
            .init(300, .debit(authorized: true),    balance: .unlimited),
            .init(300, .debit(authorized: true),    balance: .unlimited),
        ]
        
        XCTAssertEqual(expectedDemandLedger, testableSubscriber.demands)
    }
    
    func testSubscriberObeysThrottledDemandLimit() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        var testConfiguration = TestScheduler.Configuration.default
        testConfiguration.subscriberOptions.initialDemand = .max(2)
        testConfiguration.subscriberOptions.subsequentDemand = .max(2)
        
        let testablePublisher: TestablePublisher<Token, Never> = testScheduler.createTestableColdPublisher([
            
            // the first two fit within the initial demand limit and will fire as normal
            
            .init(time: 10, .init()),
            .init(time: 20, .init()),
            
            // Subsequent elements will be buffered until demand is replenished at 120. (last element time + .demandReplenishDelay)
            
            .init(time: 30, .init()), // will be delivered as soon as demand replenished at 120
            .init(time: 140, .init()), // will be delivered as scheduled as there should be remaining demand capacity of 1
        ])
        
        let testableSubscriber = testScheduler.start(configuration: testConfiguration) { testablePublisher }
        
        let expected: [TestableSubscriberEvent<Token, Never>] = [
            .init(200, .subscribe),
            .init(210, .input(.init())),
            .init(220, .input(.init())),
            .init(320, .input(.init())),
            .init(340, .input(.init())),
            .init(900, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected, testableSubscriber.events)
        
        let expectedDemandLedger: [DemandLedgerRow<VirtualTime>] = [
            .init(200, .credit(amount: .max(2)), balance: .max(2)),
            .init(210, .debit(authorized: true), balance: .max(1)),
            .init(220, .debit(authorized: true), balance: .none),
            .init(320, .credit(amount: .max(2)), balance: .max(2)),
            .init(320, .debit(authorized: true), balance: .max(1)),
            .init(340, .debit(authorized: true), balance: .none),
            .init(440, .credit(amount: .max(2)), balance: .max(2)),
        ]
        
        XCTAssertEqual(expectedDemandLedger, testableSubscriber.demands)
    }
    
    func testSubscriberSignalsOnNegativeBalance() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        var testConfiguration = TestScheduler.Configuration.default
        var didSignalNegativeBalance = false
        
        testConfiguration.subscriberOptions.initialDemand = .max(2)
        testConfiguration.subscriberOptions.negativeBalanceHandler = { didSignalNegativeBalance = true }
        
        class BadPublisher: Publisher {
            
            typealias Output = Token
            typealias Failure = Never
            
            func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
                
                // we'll send an empty subscription, as we know we're going to
                // ignore whatever the subscriber asks us to do
                
                subscriber.receive(subscription: Subscriptions.empty)
                
                // We'll send 3 events even though we know the subscriber
                // has been configure to ask for a maximum of 2
                
                _ = subscriber.receive(.init())
                _ = subscriber.receive(.init())
                _ = subscriber.receive(.init())
            }
        }
        
        let badPublisher = BadPublisher()
        
        let testableSubscriber = testScheduler.start(configuration: testConfiguration) { badPublisher }
        
        XCTAssert(didSignalNegativeBalance)
        
        
        let expectedDemandLedger: [DemandLedgerRow<VirtualTime>] = [
            .init(200, .credit(amount: .max(2)),  balance: .max(2)),
            .init(200, .debit(authorized: true),  balance: .max(1)),
            .init(200, .debit(authorized: true),  balance: .none),
            .init(200, .debit(authorized: false), balance: .max(-1)),
        ]
        
        XCTAssertEqual(expectedDemandLedger, testableSubscriber.demands)
    }
    
    func testDoesNotCreateRetainCycleWhenStreamFinishesBeforeSubscriberDeallocation() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let testablePublisher: TestablePublisher<Token, Never> = testScheduler.createTestableColdPublisher([
            .init(time: 0, .init()),
        ])
        
        var testableSubscriber: TestableSubscriber<Token, Never>! = testScheduler.start { testablePublisher }
        weak var weakTestableSubscriber = testableSubscriber
        
        let expected: [TestableSubscriberEvent<Token, Never>] = [
            .init(200, .subscribe),
            .init(200, .input(.init())),
            .init(900, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected, testableSubscriber.events)
        
        testableSubscriber = nil
        
        XCTAssertNil(weakTestableSubscriber)
    }
    
    func testDoesNotCreateRetainCycleWhenStreamCancelledBeforeSubscriberDeallocation() {
        
        var testConfiguration = TestScheduler.Configuration.default
        testConfiguration.pausedOnStart = true
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let testablePublisher: TestablePublisher<Token, Never> = testScheduler.createTestableColdPublisher([
            .init(time: 100, .init()),
        ])
        
        var testableSubscriber: TestableSubscriber<Token, Never>!
            = testScheduler.start(configuration: testConfiguration) { testablePublisher }
        weak var weakTestableSubscriber = testableSubscriber
        var earlyCancellationToken: AnyCancellable? = AnyCancellable { testableSubscriber.terminateSubscription() }
        
        XCTAssertNotNil(earlyCancellationToken)
        
        testScheduler.schedule(after: 400) { earlyCancellationToken = nil }
        
        testScheduler.resume()
        
        let expected: [TestableSubscriberEvent<Token, Never>] = [
            .init(200, .subscribe),
            .init(300, .input(.init())),
            .init(400, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected, testableSubscriber.events)
        
        testableSubscriber = nil
        
        XCTAssertNil(weakTestableSubscriber)
    }
    
    func testEnforcesSingleSubscriber() {
        
        let scheduler = TestScheduler(initialClock: 0)

        let publisher1 = PassthroughSubject<Int, Never>()
        let publisher2 = PassthroughSubject<Int, Never>()

        let subject = scheduler.createTestableSubscriber(Int.self, Never.self)

        scheduler.schedule(after: 100) { publisher1.subscribe(subject) }
        scheduler.schedule(after: 110) { publisher1.send(0) }
        scheduler.schedule(after: 200) { publisher2.subscribe(subject) }
        scheduler.schedule(after: 210) { publisher2.send(1) }
        scheduler.schedule(after: 310) { publisher1.send(2) }
        
        scheduler.resume()
        
        let expected: [TestableSubscriberEvent<Int, Never>] = [
            .init(100, .subscribe),
            .init(110, .input(0)),
            .init(310, .input(2)),
        ]
        
        XCTAssertEqual(expected, subject.events)
    }
    
    static var allTests = [
        ("testColdObservableProducesExpectedValues", testSubscriberObeysInitialDemandLimit),
        ("testSubscriberObeysSubsequentDemandLimit", testSubscriberObeysSubsequentDemandLimit),
        ("testSubscriberObeysThrottledDemandLimit", testSubscriberObeysThrottledDemandLimit),
        ("testDoesNotCreateRetainCycleWhenStreamFinishesBeforeSubscriberDeallocation", testDoesNotCreateRetainCycleWhenStreamFinishesBeforeSubscriberDeallocation),
        ("testDoesNotCreateRetainCycleWhenStreamCancelledBeforeSubscriberDeallocation", testDoesNotCreateRetainCycleWhenStreamCancelledBeforeSubscriberDeallocation),
        ("testEnforcesSingleSubscriber", testEnforcesSingleSubscriber),
    ]
}
