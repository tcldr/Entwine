//
//  Entwine
//  https://github.com/tcldr/Entwine
//
//  Copyright © 2019 Tristan Celder. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import XCTest
import Combine

@testable import Entwine
@testable import EntwineTest

final class TestableSubscriberTests: XCTestCase {
    
    struct Token: Equatable {}
    
    func testSubscriberObeysInitialDemandLimit() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        var testConfiguration = TestScheduler.Configuration.default
        testConfiguration.subscriberOptions.initialDemand = .none
        
        let testablePublisher: TestablePublisher<Token, Never> = testScheduler.createRelativeTestablePublisher([
            
            // Won't be delivered
            
            (100, .input(.init())),
            (200, .input(.init())),
            (300, .input(.init())),
        ])
        
        let testableSubscriber = testScheduler.start(configuration: testConfiguration) { testablePublisher }
        
        let expected: TestSequence<Token, Never> = [
            (200, .subscription),
        ]
        
        XCTAssertEqual(expected, testableSubscriber.sequence)
        
        let expectedDemandLedger: DemandLedger<VirtualTime> = [
            (200, .none, .credit(amount: .none))
        ]
        
        XCTAssertEqual(expectedDemandLedger, testableSubscriber.demands)
    }
    
    func testSubscriberObeysSubsequentDemandLimit() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        var testConfiguration = TestScheduler.Configuration.default
        testConfiguration.subscriberOptions.initialDemand = .none
        testConfiguration.subscriberOptions.subsequentDemand = .unlimited
        
        let testablePublisher: TestablePublisher<Token, Never> = testScheduler.createRelativeTestablePublisher([
            
            // Will all be deliverd at once when demand is replenished at (subscribe time + .demandReplenishDelay).
            
            // If inital demand was available the events would be delivered at 210, 220, and 230 respectively.
            // Howver, on subscription the initial demand is zero, so the TestableSubscriber schedules demand
            // to be replenished 100 in the future – at 300. When the demand is finally requested
            // the buffered values are delivered immediately.
            
            (10, .input(.init())),
            (20, .input(.init())),
            (30, .input(.init())),
        ])
        
        let testableSubscriber = testScheduler.start(configuration: testConfiguration) { testablePublisher }
        
        let expected: TestSequence<Token, Never> = [
            (200, .subscription),
            (300, .input(.init())),
            (300, .input(.init())),
            (300, .input(.init())),
        ]
        
        XCTAssertEqual(expected, testableSubscriber.sequence)
        
        let expectedDemandLedger: DemandLedger<VirtualTime> = [
            (200, .none,      .credit(amount: .none)),
            (300, .unlimited, .credit(amount: .unlimited)),
            (300, .unlimited, .debit(authorized: true)),
            (300, .unlimited, .debit(authorized: true)),
            (300, .unlimited, .debit(authorized: true)),
        ]
        
        XCTAssertEqual(expectedDemandLedger, testableSubscriber.demands)
    }
    
    func testSubscriberObeysThrottledDemandLimit() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        var testConfiguration = TestScheduler.Configuration.default
        testConfiguration.subscriberOptions.initialDemand = .max(2)
        testConfiguration.subscriberOptions.subsequentDemand = .max(2)
        
        let testablePublisher: TestablePublisher<Token, Never> = testScheduler.createRelativeTestablePublisher([
            
            // the first two fit within the initial demand limit and will fire as normal
            
            ( 10, .input(.init())),
            ( 20, .input(.init())),
            
            // Subsequent elements will be buffered until demand is replenished at 120. (last element time + .demandReplenishDelay)
            
            ( 30, .input(.init())), // will be delivered as soon as demand replenished at 120
            (140, .input(.init())), // will be delivered as scheduled as there should be remaining demand capacity of 1
        ])
        
        let testableSubscriber = testScheduler.start(configuration: testConfiguration) { testablePublisher }
        
        let expected: TestSequence<Token, Never> = [
            (200, .subscription),
            (210, .input(.init())),
            (220, .input(.init())),
            (320, .input(.init())),
            (340, .input(.init())),
        ]
        
        XCTAssertEqual(expected, testableSubscriber.sequence)
        
        let expectedDemandLedger: DemandLedger<VirtualTime> = [
            (200, .max(2), .credit(amount: .max(2))),
            (210, .max(1), .debit(authorized: true)),
            (220, .none,   .debit(authorized: true)),
            (320, .max(2), .credit(amount: .max(2))),
            (320, .max(1), .debit(authorized: true)),
            (340, .none,   .debit(authorized: true)),
            (440, .max(2), .credit(amount: .max(2))),
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
        
        
        let expectedDemandLedger: DemandLedger<VirtualTime> = [
            (200, .max( 2), .credit(amount: .max(2))),
            (200, .max( 1), .debit(authorized: true)),
            (200, .none,    .debit(authorized: true)),
            (200, .max(-1), .debit(authorized: false)),
        ]
        
        XCTAssertEqual(expectedDemandLedger, testableSubscriber.demands)
    }
    
    func testDoesNotCreateRetainCycleWhenStreamFinishesBeforeSubscriberDeallocation() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let testablePublisher: TestablePublisher<Token, Never> = testScheduler.createRelativeTestablePublisher([
            (0, .input(.init())),
        ])
        
        var testableSubscriber: TestableSubscriber<Token, Never>! = testScheduler.start { testablePublisher }
        weak var weakTestableSubscriber = testableSubscriber
        
        let expected: TestSequence<Token, Never> = [
            (200, .subscription),
            (200, .input(.init())),
        ]
        
        XCTAssertEqual(expected, testableSubscriber.sequence)
        
        testableSubscriber = nil
        
        XCTAssertNil(weakTestableSubscriber)
    }
    
    func testDoesNotCreateRetainCycleWhenStreamCancelledBeforeSubscriberDeallocation() {
        
        var testConfiguration = TestScheduler.Configuration.default
        testConfiguration.pausedOnStart = true
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let testablePublisher: TestablePublisher<Token, Never> = testScheduler.createRelativeTestablePublisher([
            (100, .input(.init())),
        ])
        
        var testableSubscriber: TestableSubscriber<Token, Never>!
            = testScheduler.start(configuration: testConfiguration) { testablePublisher }
        weak var weakTestableSubscriber = testableSubscriber
        var earlyCancellationToken: AnyCancellable? = AnyCancellable { testableSubscriber.cancel() }
        
        XCTAssertNotNil(earlyCancellationToken)
        
        testScheduler.schedule(after: 400) { earlyCancellationToken = nil }
        
        testScheduler.resume()
        
        let expected: TestSequence<Token, Never> = [
            (200, .subscription),
            (300, .input(.init())),
        ]
        
        XCTAssertEqual(expected, testableSubscriber.sequence)
        
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
        
        let expected: TestSequence<Int, Never> = [
            (100, .subscription),
            (110, .input(0)),
            (310, .input(2)),
        ]
        
        XCTAssertEqual(expected, subject.sequence)
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
