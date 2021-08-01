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

#if canImport(Combine)

import XCTest
import Combine

@testable import Entwine
@testable import EntwineTest

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class ReplaySubjectTests: XCTestCase {
    
    // MARK: - Properties
    
    private var scheduler: TestScheduler!
    
    // MARK: - Per test set-up and tear-down
    
    override func setUp() {
        scheduler = TestScheduler(initialClock: 0)
    }
    
    // MARK: - Tests

    func testPassesThroughValueWithBufferOfZero() {

        let subject = ReplaySubject<Int, Never>(maxBufferSize: 0)
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 100) { subject.send(0) }
        scheduler.schedule(after: 200) { subject.subscribe(results1) }
        scheduler.schedule(after: 300) { subject.send(1) }

        scheduler.resume()
        
        let expected: TestSequence<Int, Never> = [
            (200, .subscription),
            (300, .input(1)),
        ]
        
        XCTAssertEqual(expected, results1.recordedOutput)
    }

    func testPassesThroughValueWithBufferOfOne() {

        let subject = ReplaySubject<Int, Never>(maxBufferSize: 1)
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 100) { subject.send(0) }
        scheduler.schedule(after: 200) { subject.subscribe(results1) }

        scheduler.resume()
        
        let expected: TestSequence<Int, Never> = [
            (200, .subscription),
            (200, .input(0)),
        ]
        
        XCTAssertEqual(expected, results1.recordedOutput)
    }

    func testPassesThroughLatestValueWithBufferOfOne() {

        let subject = ReplaySubject<Int, Never>(maxBufferSize: 1)
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 100) { subject.send(0) }
        scheduler.schedule(after: 150) { subject.send(1) }
        scheduler.schedule(after: 200) { subject.subscribe(results1) }

        scheduler.resume()
        
        let expected: TestSequence<Int, Never> = [
            (200, .subscription),
            (200, .input(1)),
        ]
        
        XCTAssertEqual(expected, results1.recordedOutput)
    }

    func testPassesThroughCompletionIssuedPreSubscribe() {

        let subject = ReplaySubject<Int, Never>(maxBufferSize: 0)
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 100) { subject.send(completion: .finished) }
        scheduler.schedule(after: 200) { subject.subscribe(results1) }

        scheduler.resume()
        
        let expected: TestSequence<Int, Never> = [
            (200, .subscription),
            (200, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected, results1.recordedOutput)
    }

    func testPassesThroughCompletionIssuedPostSubscribe() {

        let subject = ReplaySubject<Int, Never>(maxBufferSize: 0)
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 200) { subject.subscribe(results1) }
        scheduler.schedule(after: 300) { subject.send(completion: .finished) }


        scheduler.resume()
        
        let expected: TestSequence<Int, Never> = [
            (200, .subscription),
            (300, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected, results1.recordedOutput)
    }

    func testStopsForwardingToSubscribersPostCompletion() {

        let subject = ReplaySubject<Int, Never>(maxBufferSize: 0)
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 200) { subject.subscribe(results1) }
        scheduler.schedule(after: 300) { subject.send(completion: .finished) }
        scheduler.schedule(after: 400) { subject.send(0) }


        scheduler.resume()
        
        let expected1: TestSequence<Int, Never> = [
            (200, .subscription),
            (300, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected1, results1.recordedOutput)
    }

    func testImmediatelyCompletesForNewSubscribersPostPreviousCompletion() {

        let subject = ReplaySubject<Int, Never>(maxBufferSize: 0)
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let results2 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 200) { subject.subscribe(results1) }
        scheduler.schedule(after: 300) { subject.send(0) }
        scheduler.schedule(after: 400) { subject.send(completion: .finished) }
        
        scheduler.schedule(after: 500) { subject.subscribe(results2) }
        scheduler.schedule(after: 600) { subject.send(0) }
        scheduler.schedule(after: 700) { subject.send(completion: .finished) }

        scheduler.resume()
        
        let expected1: TestSequence<Int, Never> = [
            (200, .subscription),
            (300, .input(0)),
            (400, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected1, results1.recordedOutput)
        
        let expected2: TestSequence<Int, Never> = [
            (500, .subscription),
            (500, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected2, results2.recordedOutput)
    }

    func testHasNoSubscribers() {

        var subject: ReplaySubject<Int, Never>! = nil
        
        scheduler.schedule(after: 100) { subject = ReplaySubject(maxBufferSize: 1) }
        scheduler.schedule(after: 250) { XCTAssertEqual(0, subject.subscriptionCount) }

        scheduler.resume()
    }

    func testHasOneSubscriber() {

        var subject: ReplaySubject<Int, Never>! = nil

        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)

        scheduler.schedule(after: 100) { subject = ReplaySubject(maxBufferSize: 1) }
        scheduler.schedule(after: 250) { XCTAssertEqual(0, subject.subscriptionCount) }
        scheduler.schedule(after: 300) { subject.subscribe(results1) }
        scheduler.schedule(after: 350) { XCTAssertEqual(1, subject.subscriptionCount) }
        scheduler.schedule(after: 400) { results1.cancel() }
        scheduler.schedule(after: 450) { XCTAssertEqual(0, subject.subscriptionCount) }

        scheduler.resume()
    }

    func testHasManySubscribers() {

        var subject: ReplaySubject<Int, Never>! = nil

        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let results2 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let results3 = scheduler.createTestableSubscriber(Int.self, Never.self)

        scheduler.schedule(after: 100) { subject = ReplaySubject(maxBufferSize: 1) }
        scheduler.schedule(after: 250) { XCTAssertEqual(0, subject.subscriptionCount) }
        scheduler.schedule(after: 300) { subject.subscribe(results1) }
        scheduler.schedule(after: 301) { subject.subscribe(results2) }
        scheduler.schedule(after: 302) { subject.subscribe(results3) }
        scheduler.schedule(after: 350) { XCTAssertEqual(3, subject.subscriptionCount) }
        scheduler.schedule(after: 400) { results1.cancel() }
        scheduler.schedule(after: 405) { XCTAssertEqual(2, subject.subscriptionCount) }
        scheduler.schedule(after: 410) { results2.cancel() }
        scheduler.schedule(after: 415) { XCTAssertEqual(1, subject.subscriptionCount) }
        scheduler.schedule(after: 420) { results3.cancel() }
        scheduler.schedule(after: 450) { XCTAssertEqual(0, subject.subscriptionCount) }
        
        scheduler.resume()
    }
    
    func testReplaysValuesToNewSubscribersPostCompletion() {
        
        var subject: ReplaySubject<Int, Never>! = nil
        
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 100) { subject = ReplaySubject(maxBufferSize: 2) }
        scheduler.schedule(after: 110) { subject.send(0) }
        scheduler.schedule(after: 120) { subject.send(1) }
        scheduler.schedule(after: 130) { subject.send(2) }
        scheduler.schedule(after: 140) { subject.send(completion: .finished) }
        scheduler.schedule(after: 200) { subject.subscribe(results1) }
        
        scheduler.resume()
        
        let expected1: TestSequence<Int, Never> = [
            (200, .subscription),
            (200, .input(1)),
            (200, .input(2)),
            (200, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected1, results1.recordedOutput)
    }
    
    func testReplaysZeroValuesPassthroughSubjectControl() {
        
        var subject: PassthroughSubject<Int, Never>! = nil
        
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 100) { subject = PassthroughSubject() }
        scheduler.schedule(after: 200) { subject.subscribe(results1) }
        scheduler.schedule(after: 300) { subject.send(1) }
        scheduler.schedule(after: 400) { results1.cancel() }
        
        scheduler.resume()
        
        let expected1: TestSequence<Int, Never> = [
            (200, .subscription),
            (300, .input(1)),
        ]
        
        XCTAssertEqual(expected1, results1.recordedOutput)
    }
    
    func testReplaysZeroValues() {
        
        var subject: ReplaySubject<Int, Never>! = nil
        
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 100) { subject = ReplaySubject(maxBufferSize: 0) }
        scheduler.schedule(after: 200) { subject.subscribe(results1) }
        scheduler.schedule(after: 300) { subject.send(1) }
        scheduler.schedule(after: 400) { results1.cancel() }
        
        scheduler.resume()
        
        let expected1: TestSequence<Int, Never> = [
            (200, .subscription),
            (300, .input(1)),
        ]
        
        XCTAssertEqual(expected1, results1.recordedOutput)
    }
    
    func testReplaysOneValue() {
        
        var subject: ReplaySubject<Int, Never>! = nil
        
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 100) { subject = ReplaySubject(maxBufferSize: 1) }
        scheduler.schedule(after: 200) { subject.send(1) }
        scheduler.schedule(after: 300) { subject.subscribe(results1) }
        scheduler.schedule(after: 400) { subject.send(2) }
        scheduler.schedule(after: 500) { results1.cancel() }
        
        scheduler.resume()
        
        let expected1: TestSequence<Int, Never> = [
            (300, .subscription),
            (300, .input(1)),
            (400, .input(2)),
        ]
        
        XCTAssertEqual(expected1, results1.recordedOutput)
    }
    
    func testReplaysTwoValues() {
        
        var subject: ReplaySubject<Int, Never>! = nil
        
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 100) { subject = ReplaySubject(maxBufferSize: 2) }
        scheduler.schedule(after: 200) { subject.send(1) }
        scheduler.schedule(after: 300) { subject.send(2) }
        scheduler.schedule(after: 400) { subject.send(3) }
        scheduler.schedule(after: 500) { subject.subscribe(results1) }
        scheduler.schedule(after: 600) { subject.send(4) }
        scheduler.schedule(after: 700) { subject.send(5) }
        scheduler.schedule(after: 800) { results1.cancel() }
        
        scheduler.resume()
        
        let expected1: TestSequence<Int, Never> = [
            (500, .subscription),
            (500, .input(2)),
            (500, .input(3)),
            (600, .input(4)),
            (700, .input(5)),
        ]
        
        XCTAssertEqual(expected1, results1.recordedOutput)
    }
    
    func testReplaysToManySubscribers() {
        
        var subject: ReplaySubject<Int, Never>! = nil
        
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let results2 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let results3 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 100) { subject = ReplaySubject(maxBufferSize: 1) }
        scheduler.schedule(after: 200) { subject.send(1) }
        scheduler.schedule(after: 300) { subject.subscribe(results1) }
        scheduler.schedule(after: 300) { subject.subscribe(results2) }
        scheduler.schedule(after: 300) { subject.subscribe(results3) }
        scheduler.schedule(after: 400) { subject.send(2) }
        scheduler.schedule(after: 500) { results1.cancel() }
        scheduler.schedule(after: 500) { results2.cancel() }
        scheduler.schedule(after: 500) { results3.cancel() }
        
        scheduler.resume()
        
        let expected1: TestSequence<Int, Never> = [
            (300, .subscription),
            (300, .input(1)),
            (400, .input(2)),
        ]
        
        XCTAssertEqual(expected1, results3.recordedOutput)
        XCTAssertEqual(expected1, results2.recordedOutput)
        XCTAssertEqual(expected1, results3.recordedOutput)
    }
    
    func testCancelPropagationDownstreamMatchesControl() {
        
        var subject: ReplaySubject<Int, Never>! = nil
        var control: PassthroughSubject<Int, Never>! = nil
        
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let results2 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 100) { subject = ReplaySubject(maxBufferSize: 1) }
        scheduler.schedule(after: 200) { subject.subscribe(results1) }
        scheduler.schedule(after: 300) { results1.cancel() }
        
        scheduler.schedule(after: 100) { control = PassthroughSubject() }
        scheduler.schedule(after: 200) { control.subscribe(results2) }
        scheduler.schedule(after: 300) { results2.cancel() }
        
        scheduler.resume()
        
        XCTAssertEqual(results1.recordedOutput, results2.recordedOutput)
    }
    
    func testDeallocationBehaviorMatchesControl() {
        
        var subject: ReplaySubject<Int, Never>! = nil
        var control: PassthroughSubject<Int, Never>! = nil
        
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let results2 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 100) { subject = ReplaySubject(maxBufferSize: 0) }
        scheduler.schedule(after: 100) { control = PassthroughSubject() }
        scheduler.schedule(after: 200) { subject.subscribe(results1) }
        scheduler.schedule(after: 200) { control.subscribe(results2) }
        scheduler.schedule(after: 300) { subject.send(0) }
        scheduler.schedule(after: 300) { control.send(0) }
        scheduler.schedule(after: 400) { subject = nil }
        scheduler.schedule(after: 400) { control = nil }
        
        scheduler.resume()
        
        XCTAssertEqual(results2.recordedOutput, results1.recordedOutput)
    }
    
    func testReentrancyBehaviorMatchesControl() {
        
        var subject: ReplaySubject<Int, Never>! = nil
        var control: PassthroughSubject<Int, Never>! = nil
        
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let results2 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 100) { subject = ReplaySubject(maxBufferSize: 1) }
        scheduler.schedule(after: 100) { control = PassthroughSubject() }
        scheduler.schedule(after: 200) { subject.subscribe(results1) }
        scheduler.schedule(after: 200) { control.subscribe(results2) }
        scheduler.schedule(after: 300) { self.performSubjectReentrancyTest(subject, count: 10) }
        scheduler.schedule(after: 300) { self.performSubjectReentrancyTest(control, count: 10) }
        scheduler.schedule(after: 400) { subject = nil }
        scheduler.schedule(after: 400) { control = nil }
        
        scheduler.resume()
        
        XCTAssertEqual(results2.recordedOutput, results1.recordedOutput)
    }
    
    func testDuplicateSubscriptionMatchesControl() {
        
        var subject: ReplaySubject<Int, Never>! = nil
        var control: PassthroughSubject<Int, Never>! = nil
        
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let results2 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 100) { subject = ReplaySubject(maxBufferSize: 1) }
        scheduler.schedule(after: 100) { control = PassthroughSubject() }
        scheduler.schedule(after: 200) { subject.subscribe(results1) }
        scheduler.schedule(after: 200) { control.subscribe(results2) }
        scheduler.schedule(after: 300) { subject.subscribe(results1) }
        scheduler.schedule(after: 300) { control.subscribe(results2) }
        scheduler.schedule(after: 400) { subject = nil }
        scheduler.schedule(after: 400) { control = nil }
        
        scheduler.resume()
        
        XCTAssertEqual(results2.recordedOutput, results1.recordedOutput)
    }

    func testSendSubscriptionInitialDemandUnlimitedBehaviorMatchesControl() {
        
        let subject = ReplaySubject<Int, Never>(maxBufferSize: 0)
        let control = PassthroughSubject<Int, Never>()
        
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let results2 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        let subjectSubscription = TestSubscription()
        let controlSubscription = TestSubscription()
        
        scheduler.schedule(after: 100) { subject.send(subscription: subjectSubscription) }
        scheduler.schedule(after: 100) { control.send(subscription: controlSubscription) }
        scheduler.schedule(after: 200) { subject.subscribe(results1) }
        scheduler.schedule(after: 200) { control.subscribe(results2) }
        scheduler.schedule(after: 300) { XCTAssertEqual(subjectSubscription.demand, .some(.unlimited)) }
        scheduler.schedule(after: 300) { XCTAssertEqual(controlSubscription.demand, .some(.unlimited)) }
        scheduler.schedule(after: 400) { subject.send(1) }
        scheduler.schedule(after: 400) { control.send(1) }
        
        scheduler.resume()
        
        XCTAssertEqual(results2.recordedOutput, results1.recordedOutput)
    }

    func testSendSubscriptionInitialDemandOneBehaviorMatchesControl() {
        
        let subject = ReplaySubject<Int, Never>(maxBufferSize: 0)
        let control = PassthroughSubject<Int, Never>()
        
        var options = TestableSubscriberOptions.default
        options.initialDemand = .max(1)
        
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self, options: options)
        let results2 = scheduler.createTestableSubscriber(Int.self, Never.self, options: options)
        
        let subjectSubscription = TestSubscription()
        let controlSubscription = TestSubscription()
        
        scheduler.schedule(after: 100) { subject.send(subscription: subjectSubscription) }
        scheduler.schedule(after: 100) { control.send(subscription: controlSubscription) }
        scheduler.schedule(after: 200) { subject.subscribe(results1) }
        scheduler.schedule(after: 200) { control.subscribe(results2) }
        scheduler.schedule(after: 300) { XCTAssertEqual(subjectSubscription.demand, .some(.unlimited)) }
        scheduler.schedule(after: 300) { XCTAssertEqual(controlSubscription.demand, .some(.unlimited)) }
        scheduler.schedule(after: 400) { subject.send(1) }
        scheduler.schedule(after: 400) { control.send(1) }
        
        scheduler.resume()
        
        XCTAssertEqual(results2.recordedOutput, results1.recordedOutput)
    }
    
    // MARK: - Helper methods
    
    func performSubjectReentrancyTest<S: Subject>(_ subject: S, count: Int, i: Int = 0) where S.Output == Int {
        guard i < count else { return }
        scheduler.schedule {
            self.performSubjectReentrancyTest(subject, count: count, i: i + 1)
            subject.send(i)
        }
    }
}

// MARK: - Test types

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
fileprivate final class TestSubscription: Subscription {
    func request(_ demand: Subscribers.Demand) {
        self.demand = demand
    }
    
    func cancel() {
        cancelled = true
    }
    
    var cancelled = false
    var demand: Subscribers.Demand?
}

#endif
