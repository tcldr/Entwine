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
        
        XCTAssertEqual(expected, results1.sequence)
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
        
        XCTAssertEqual(expected, results1.sequence)
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
        
        XCTAssertEqual(expected, results1.sequence)
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
        
        XCTAssertEqual(expected, results1.sequence)
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
        
        XCTAssertEqual(expected, results1.sequence)
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
        
        XCTAssertEqual(expected1, results1.sequence)
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
        
        XCTAssertEqual(expected1, results1.sequence)
        
        let expected2: TestSequence<Int, Never> = [
            (500, .subscription),
            (500, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected2, results2.sequence)
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
            (400, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected1, results1.sequence)
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
            (500, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected1, results1.sequence)
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
            (800, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected1, results1.sequence)
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
            (500, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected1, results3.sequence)
        XCTAssertEqual(expected1, results2.sequence)
        XCTAssertEqual(expected1, results3.sequence)
    }
    
    func testCancelPropagatesDownstream() {
        
        var subject: ReplaySubject<Int, Never>! = nil
        
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 100) { subject = ReplaySubject(maxBufferSize: 1) }
        scheduler.schedule(after: 200) { subject.subscribe(results1) }
        scheduler.schedule(after: 300) { results1.cancel() }
        
        scheduler.resume()
        
        let expected1: TestSequence<Int, Never> = [
            (200, .subscription),
            (300, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected1, results1.sequence)
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
        
        XCTAssertEqual(results2.sequence, results1.sequence)
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
        
        XCTAssertEqual(results2.sequence, results1.sequence)
    }
    
    func performSubjectReentrancyTest<S: Subject>(_ subject: S, count: Int, i: Int = 0) where S.Output == Int {
        guard i < count else { return }
        scheduler.schedule {
            self.performSubjectReentrancyTest(subject, count: count, i: i + 1)
            subject.send(i)
        }
    }
}
