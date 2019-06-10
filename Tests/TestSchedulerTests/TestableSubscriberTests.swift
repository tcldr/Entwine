
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
            .subscribe(time: testConfiguration.subscribed),
            .completion(time: testConfiguration.cancelled, .finished)
        ]
        
        XCTAssertEqual(expected, testableSubscriber.events)
        
        let expectedDemandLedger: [DemandLedgerRow<VirtualTime>] = [
            .credit(time: 200, amount: .none, balance: .none),
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
            .subscribe(time: testConfiguration.subscribed),
            .input(time: 300, .init()),
            .input(time: 300, .init()),
            .input(time: 300, .init()),
            .completion(time: testConfiguration.cancelled, .finished)
        ]
        
        XCTAssertEqual(expected, testableSubscriber.events)
        
        let expectedDemandLedger: [DemandLedgerRow<VirtualTime>] = [
            .credit(time: 200, amount: .none, balance: .none),
            .credit(time: 300, amount: .unlimited, balance: .unlimited),
            .debit(time: 300, balance: .unlimited, authorized: true),
            .debit(time: 300, balance: .unlimited, authorized: true),
            .debit(time: 300, balance: .unlimited, authorized: true),
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
            .subscribe(time: testConfiguration.subscribed),
            .input(time: 210, .init()),
            .input(time: 220, .init()),
            .input(time: 320, .init()),
            .input(time: 340, .init()),
            .completion(time: testConfiguration.cancelled, .finished)
        ]
        
        XCTAssertEqual(expected, testableSubscriber.events)
        
        let expectedDemandLedger: [DemandLedgerRow<VirtualTime>] = [
            .credit(time: 200, amount: .max(2), balance: .max(2)),
            .debit(time: 210, balance: .max(1), authorized: true),
            .debit(time: 220, balance: .none, authorized: true),
            .credit(time: 320, amount: .max(2), balance: .max(2)),
            .debit(time: 320, balance: .max(1), authorized: true),
            .debit(time: 340, balance: .none, authorized: true),
            .credit(time: 440, amount: .max(2), balance: .max(2)),
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
            .credit(time: 200, amount: .max(2), balance: .max(2)),
            .debit(time: 200, balance: .max(1), authorized: true),
            .debit(time: 200, balance: .none, authorized: true),
            .debit(time: 200, balance: .max(-1), authorized: false),
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
            .subscribe(time: 200),
            .input(time: 200, .init()),
            .completion(time: 1000, .finished)
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
        var earlyCancellationToken: AnyCancellable? = AnyCancellable { testableSubscriber.cancel() }
        
        XCTAssertNotNil(earlyCancellationToken)
        
        testScheduler.schedule(after: 400) { earlyCancellationToken = nil }
        
        testScheduler.resume()
        
        let expected: [TestableSubscriberEvent<Token, Never>] = [
            .subscribe(time: 200),
            .input(time: 300, .init()),
            .completion(time: 400, .finished)
        ]
        
        XCTAssertEqual(expected, testableSubscriber.events)
        
        testableSubscriber = nil
        
        XCTAssertNil(weakTestableSubscriber)
    }
    
    static var allTests = [
        ("testColdObservableProducesExpectedValues", testSubscriberObeysInitialDemandLimit),
        ("testSubscriberObeysSubsequentDemandLimit", testSubscriberObeysSubsequentDemandLimit),
        ("testSubscriberObeysThrottledDemandLimit", testSubscriberObeysThrottledDemandLimit),
        ("testDoesNotCreateRetainCycleWhenStreamFinishesBeforeSubscriberDeallocation", testDoesNotCreateRetainCycleWhenStreamFinishesBeforeSubscriberDeallocation),
        ("testDoesNotCreateRetainCycleWhenStreamCancelledBeforeSubscriberDeallocation", testDoesNotCreateRetainCycleWhenStreamCancelledBeforeSubscriberDeallocation),
    ]
}
