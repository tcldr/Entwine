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

final class WithLatestFromTests: XCTestCase {
    
    func testTakesOnlyLatestValueFromOther() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let testablePublisher: TestablePublisher<String, Never> = testScheduler.createTestableColdPublisher([
            (010, .input("x")),
            (020, .input("y")),
            (030, .input("z")),
        ])
        
        let testablePublisherOther: TestablePublisher<String, Never> = testScheduler.createTestableColdPublisher([
            (001, .input("a")),
            (002, .input("b")),
            (003, .input("c")),
        ])
        
        let testableSubscriber = testScheduler.start { testablePublisher.withLatest(from: testablePublisherOther)  }
        
        let expected: TestSequence<String, Never> = [
            (200, .subscription),
            (210, .input("c")),
            (220, .input("c")),
            (230, .input("c")),
            (900, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected, testableSubscriber.sequence)
    }
    
    func testDropsUpstreamValuesReceivedPriorToFirstOtherValue() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let testablePublisher: TestablePublisher<String, Never> = testScheduler.createTestableColdPublisher([
            (010, .input("x")),
            (020, .input("y")),
            (030, .input("z")),
        ])
        
        let testablePublisherOther: TestablePublisher<String, Never> = testScheduler.createTestableColdPublisher([
            (015, .input("a")),
            (025, .input("b")),
            (035, .input("c")),
        ])
        
        let testableSubscriber = testScheduler.start { testablePublisher.withLatest(from: testablePublisherOther)  }
        
        let expected: TestSequence<String, Never> = [
            (200, .subscription),
            (220, .input("a")),
            (230, .input("b")),
            (900, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected, testableSubscriber.sequence)
    }
    
    func testMatchesLimitedSubscriberDemand() {
        
        let testScheduler = TestScheduler(initialClock: 0)
        
        let testablePublisher: TestablePublisher<String, Never> = testScheduler.createTestableColdPublisher([
            (010, .input("x")),
            (020, .input("y")),
            (030, .input("z")),
        ])
        
        let testablePublisherOther: TestablePublisher<String, Never> = testScheduler.createTestableColdPublisher([
            (000, .input("a")),
            (001, .input("b")),
            (002, .input("c")),
        ])
        
        var configuration = TestScheduler.Configuration.default
        configuration.subscriberOptions.initialDemand = .max(1)
        
        let testableSubscriber = testScheduler.start(configuration: configuration) { testablePublisher.withLatest(from: testablePublisherOther)  }
        
        let expected: TestSequence<String, Never> = [
            (200, .subscription),
            (210, .input("c")),
            (900, .completion(.finished)),
        ]
        
        XCTAssertEqual(expected, testableSubscriber.sequence)
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
