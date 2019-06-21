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
        
        let expected1: [SignalEvent<Signal<Int, Never>>] = [
            .init(100, .subscription),
            .init(200, .input(0)),
            .init(400, .input(1)),
        ]
        
        XCTAssertEqual(expected1, results1.events)
        
        let expected2: [SignalEvent<Signal<Int, Never>>] = [
            .init(300, .subscription),
            .init(400, .input(1)),
        ]
        
        XCTAssertEqual(expected2, results2.events)
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
        
        let expected1: [SignalEvent<Signal<Int, Never>>] = [
            .init(100, .subscription),
            .init(200, .input(0)),
            .init(400, .input(1)),
        ]
        
        XCTAssertEqual(expected1, results1.events)
        
        let expected2: [SignalEvent<Signal<Int, Never>>] = [
            .init(300, .subscription),
            .init(300, .input(0)),
            .init(400, .input(1)),
        ]
        
        XCTAssertEqual(expected2, results2.events)
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
        
        let expected1: [SignalEvent<Signal<Int, Never>>] = [
            .init(100, .subscription),
            .init(200, .input(0)),
            .init(250, .input(1)),
            .init(400, .input(2)),
        ]
        
        XCTAssertEqual(expected1, results1.events)
        
        let expected2: [SignalEvent<Signal<Int, Never>>] = [
            .init(300, .subscription),
            .init(300, .input(1)),
            .init(400, .input(2)),
        ]
        
        XCTAssertEqual(expected2, results2.events)
    }

    func testPassesThroughCompletionIssuedPreSubscribe() {

        let subject = PassthroughSubject<Int, Never>()
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let sut = subject.share(replay: 0)
        
        scheduler.schedule(after: 100) { subject.send(completion: .finished) }
        scheduler.schedule(after: 200) { sut.subscribe(results1) }

        scheduler.resume()
        
        let expected: [SignalEvent<Signal<Int, Never>>] = [
            .init(200, .subscription),
            .init(200, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected, results1.events)
    }

    func testPassesThroughCompletionIssuedPostSubscribe() {

        let subject = PassthroughSubject<Int, Never>()
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let sut = subject.share(replay: 0)
        
        scheduler.schedule(after: 200) { sut.subscribe(results1) }
        scheduler.schedule(after: 300) { subject.send(completion: .finished) }


        scheduler.resume()
        
        let expected: [SignalEvent<Signal<Int, Never>>] = [
            .init(200, .subscription),
            .init(300, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected, results1.events)
    }

    func testStopsForwardingToSubscribersPostCompletion() {

        let subject = PassthroughSubject<Int, Never>()
        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let sut = subject.share(replay: 0)
        
        scheduler.schedule(after: 200) { sut.subscribe(results1) }
        scheduler.schedule(after: 300) { subject.send(completion: .finished) }
        scheduler.schedule(after: 400) { subject.send(0) }


        scheduler.resume()
        
        let expected1: [SignalEvent<Signal<Int, Never>>] = [
            .init(200, .subscription),
            .init(300, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected1, results1.events)
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
        
        let expected1: [SignalEvent<Signal<Int, Never>>] = [
            .init(200, .subscription),
            .init(300, .input(0)),
            .init(400, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected1, results1.events)
        
        let expected2: [SignalEvent<Signal<Int, Never>>] = [
            .init(500, .subscription),
            .init(500, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected2, results2.events)
    }
}
