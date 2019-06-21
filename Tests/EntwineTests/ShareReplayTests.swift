//
//  File.swift
//  
//
//  Created by Tristan Celder on 19/06/2019.
//

import XCTest
import Combine

@testable import Entwine
@testable import EntwineTest

final class ShareReplayTests: XCTestCase {
    
    // MARK: - Properties
    
    private var scheduler: TestScheduler!
    
    // MARK: - Per test set-up and tear-down
    
    override func setUp() {
        scheduler = TestScheduler(initialClock: 0)
    }
    
    // MARK: - Tests

    func testPassesThroughValueWithBufferOfZero() {

        let subject = PassthroughSubject<Int, Never>()
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let results2 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let sut = subject.share(replay: 0)
        
        scheduler.schedule(after: 100) { sut.subscribe(results1) }
        scheduler.schedule(after: 200) { subject.send(0) }
        scheduler.schedule(after: 300) { sut.subscribe(results2) }
        scheduler.schedule(after: 400) { subject.send(1) }

        scheduler.resume()
        
        let expected1: TestSequence<Int, Never> = [
            (100, .subscription),
            (200, .input(0)),
            (400, .input(1)),
        ]
        
        XCTAssertEqual(expected1, results1.sequence)
        
        let expected2: TestSequence<Int, Never> = [
            (300, .subscription),
            (400, .input(1)),
        ]
        
        XCTAssertEqual(expected2, results2.sequence)
    }

    func testPassesThroughValueWithBufferOfOne() {

        let subject = PassthroughSubject<Int, Never>()
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let results2 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let sut = subject.share(replay: 1)
        
        scheduler.schedule(after: 100) { sut.subscribe(results1) }
        scheduler.schedule(after: 200) { subject.send(0) }
        scheduler.schedule(after: 300) { sut.subscribe(results2) }
        scheduler.schedule(after: 400) { subject.send(1) }

        scheduler.resume()
        
        let expected1: TestSequence<Int, Never> = [
            (100, .subscription),
            (200, .input(0)),
            (400, .input(1)),
        ]
        
        XCTAssertEqual(expected1, results1.sequence)
        
        let expected2: TestSequence<Int, Never> = [
            (300, .subscription),
            (300, .input(0)),
            (400, .input(1)),
        ]
        
        XCTAssertEqual(expected2, results2.sequence)
    }

    func testPassesThroughLatestValueWithBufferOfOne() {

        let subject = PassthroughSubject<Int, Never>()
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let results2 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let sut = subject.share(replay: 1)
        
        scheduler.schedule(after: 100) { sut.subscribe(results1) }
        scheduler.schedule(after: 200) { subject.send(0) }
        scheduler.schedule(after: 250) { subject.send(1) }
        scheduler.schedule(after: 300) { sut.subscribe(results2) }
        scheduler.schedule(after: 400) { subject.send(2) }

        scheduler.resume()
        
        let expected1: TestSequence<Int, Never> = [
            (100, .subscription),
            (200, .input(0)),
            (250, .input(1)),
            (400, .input(2)),
        ]
        
        XCTAssertEqual(expected1, results1.sequence)
        
        let expected2: TestSequence<Int, Never> = [
            (300, .subscription),
            (300, .input(1)),
            (400, .input(2)),
        ]
        
        XCTAssertEqual(expected2, results2.sequence)
    }

    func testPassesThroughCompletionIssuedPreSubscribe() {

        let subject = PassthroughSubject<Int, Never>()
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let sut = subject.share(replay: 0)
        
        scheduler.schedule(after: 100) { subject.send(completion: .finished) }
        scheduler.schedule(after: 200) { sut.subscribe(results1) }

        scheduler.resume()
        
        let expected: TestSequence<Int, Never> = [
            (200, .subscription),
            (200, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected, results1.sequence)
    }

    func testPassesThroughCompletionIssuedPostSubscribe() {

        let subject = PassthroughSubject<Int, Never>()
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let sut = subject.share(replay: 0)
        
        scheduler.schedule(after: 200) { sut.subscribe(results1) }
        scheduler.schedule(after: 300) { subject.send(completion: .finished) }


        scheduler.resume()
        
        let expected: TestSequence<Int, Never> = [
            (200, .subscription),
            (300, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected, results1.sequence)
    }

    func testStopsForwardingToSubscribersPostCompletion() {

        let subject = PassthroughSubject<Int, Never>()
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let sut = subject.share(replay: 0)
        
        scheduler.schedule(after: 200) { sut.subscribe(results1) }
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

        let subject = PassthroughSubject<Int, Never>()
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let results2 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let sut = subject.share(replay: 0)
        
        scheduler.schedule(after: 200) { sut.subscribe(results1) }
        scheduler.schedule(after: 300) { subject.send(0) }
        scheduler.schedule(after: 400) { subject.send(completion: .finished) }
        
        scheduler.schedule(after: 500) { sut.subscribe(results2) }
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
}
