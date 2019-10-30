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
        
        XCTAssertEqual(expected1, results1.recordedOutput)
        
        let expected2: TestSequence<Int, Never> = [
            (300, .subscription),
            (400, .input(1)),
        ]
        
        XCTAssertEqual(expected2, results2.recordedOutput)
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
        
        XCTAssertEqual(expected1, results1.recordedOutput)
        
        let expected2: TestSequence<Int, Never> = [
            (300, .subscription),
            (300, .input(0)),
            (400, .input(1)),
        ]
        
        XCTAssertEqual(expected2, results2.recordedOutput)
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
        
        XCTAssertEqual(expected1, results1.recordedOutput)
        
        let expected2: TestSequence<Int, Never> = [
            (300, .subscription),
            (300, .input(1)),
            (400, .input(2)),
        ]
        
        XCTAssertEqual(expected2, results2.recordedOutput)
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
        
        XCTAssertEqual(expected, results1.recordedOutput)
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
        
        XCTAssertEqual(expected, results1.recordedOutput)
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
        
        XCTAssertEqual(expected1, results1.recordedOutput)
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
        
        XCTAssertEqual(expected1, results1.recordedOutput)
        
        let expected2: TestSequence<Int, Never> = [
            (500, .subscription),
            (500, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected2, results2.recordedOutput)
    }
    
    func testPassesThroughInitialValueToFirstSubscriberOnly() {
        
        let passthrough = PassthroughSubject<Int, Never>()
        let subject = passthrough.prepend(-1).share()

        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let results2 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 100) { subject.subscribe(results1) }
        scheduler.schedule(after: 110) { subject.subscribe(results2) }
        scheduler.schedule(after: 200) { passthrough.send(0) }
        scheduler.schedule(after: 210) { passthrough.send(1) }

        scheduler.resume()
        
        let expected2: TestSequence<Int, Never> = [
            (110, .subscription),
            (200, .input( 0)),
            (210, .input( 1)),
        ]
        
        XCTAssertEqual(expected2, results2.recordedOutput)
    }
    
    func testResetsWhenReferenceCountReachesZero() {

        let passthrough = PassthroughSubject<Int, Never>()
        let subject = passthrough.prepend(-1).share(replay: 2)

        let results1 = scheduler.createTestableSubscriber(Int.self, Never.self)
        let results2 = scheduler.createTestableSubscriber(Int.self, Never.self)
        
        scheduler.schedule(after: 100) { subject.subscribe(results1) }
        scheduler.schedule(after: 110) { passthrough.send(0) }
        scheduler.schedule(after: 200) { results1.cancel() }
        scheduler.schedule(after: 200) { subject.subscribe(results2) }
        scheduler.schedule(after: 300) { passthrough.send(5) }
        scheduler.schedule(after: 310) { passthrough.send(6) }

        scheduler.resume()
        
        let expected1: TestSequence<Int, Never> = [
            (100, .subscription),
            (100, .input(-1)),
            (110, .input( 0)),
        ]
        
        let expected2: TestSequence<Int, Never> = [
            (200, .subscription),
            (200, .input(-1)),
            (300, .input( 5)),
            (310, .input( 6)),
        ]
        
        XCTAssertEqual(expected1, results1.recordedOutput)
        XCTAssertEqual(expected2, results2.recordedOutput)
    }
}
